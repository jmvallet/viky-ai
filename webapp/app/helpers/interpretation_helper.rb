module InterpretationHelper

  def rtl?(locale)
    locale == 'ar'
  end

  def intent_to_json(intent)
    JSON.generate(
      color:  "intent-#{intent.color}",
      aliasname: intent.intentname,
      slug: intent.slug,
      interpretation_aliasable_id: intent.id,
      interpretation_aliasable_type: Intent.name,
      nature: InterpretationAlias.natures.key(InterpretationAlias.natures[:type_intent])
    )
  end

  def entities_list_to_json(entities_list)
    JSON.generate(
      color:  "entities_list-#{entities_list.color}",
      aliasname: entities_list.listname,
      slug: entities_list.slug,
      interpretation_aliasable_id: entities_list.id,
      interpretation_aliasable_type: EntitiesList.name,
      nature: InterpretationAlias.natures.key(InterpretationAlias.natures[:type_entities_list])
    )
  end

  def number_to_json
    JSON.generate({
      color:  "intent-black",
      aliasname: t("views.interpretations.number").downcase,
      nature: InterpretationAlias.natures.key(InterpretationAlias.natures[:type_number])
    })
  end

  def regex_to_json
    JSON.generate({
      color: "intent-black",
      aliasname: t("views.interpretations.regex").downcase,
      nature: InterpretationAlias.natures.key(InterpretationAlias.natures[:type_regex]),
      reg_exp: ""
    })
  end

  def alias_to_json_href(interpretation_alias)
    ERB::Util.url_encode(alias_to_json(interpretation_alias))
  end

  def alias_to_json(interpretation_alias)
    if interpretation_alias.type_number?
      data = {
        color: "intent-black",
        aliasname: interpretation_alias.aliasname,
        nature: InterpretationAlias.natures.key(InterpretationAlias.natures[:type_number]),
        is_list: interpretation_alias.is_list,
        any_enabled: interpretation_alias.any_enabled,
        slug: t("views.interpretations.number")
      }
    elsif interpretation_alias.type_regex?
      data = {
        color: "intent-black",
        aliasname: interpretation_alias.aliasname,
        nature: InterpretationAlias.natures.key(InterpretationAlias.natures[:type_regex]),
        reg_exp: interpretation_alias.reg_exp,
        is_list: interpretation_alias.is_list,
        any_enabled: interpretation_alias.any_enabled,
        slug: t("views.interpretations.regex")
      }
    else
      current_aliasable = interpretation_alias.interpretation_aliasable
      url = nil
      if current_user.can?(:show, current_aliasable.agent)
        if interpretation_alias.type_intent?
          url = user_agent_intent_path(current_aliasable.agent.owner, current_aliasable.agent, current_aliasable)
        elsif interpretation_alias.type_entities_list?
          url = user_agent_entities_list_path(current_aliasable.agent.owner, current_aliasable.agent, current_aliasable)
        end
      end
      data = {
        aliasname: interpretation_alias.aliasname,
        slug: current_aliasable.slug,
        interpretation_aliasable_id: current_aliasable.id,
        is_list: interpretation_alias.is_list,
        any_enabled: interpretation_alias.any_enabled,
        url: url,
      }
      if interpretation_alias.type_intent?
        data[:color] = "intent-#{current_aliasable.color}"
        data[:interpretation_aliasable_type] = Intent.name
        data[:nature] = InterpretationAlias.natures.key(InterpretationAlias.natures[:type_intent])
      end
      if interpretation_alias.type_entities_list?
        data[:color] = "entities_list-#{current_aliasable.color}"
        data[:interpretation_aliasable_type] = EntitiesList.name
        data[:nature] = InterpretationAlias.natures.key(InterpretationAlias.natures[:type_entities_list])
      end
    end
    data[:id] = interpretation_alias.id unless interpretation_alias.id.nil?

    unless interpretation_alias.errors[:aliasname].empty?
      data[:aliasname_errors] = display_errors(interpretation_alias, :aliasname)
    end

    unless interpretation_alias.errors[:reg_exp].empty?
      data[:regex_errors] = display_errors(interpretation_alias, :reg_exp)
    end

    unless interpretation_alias.errors[:base].empty?
      data[:base_errors] = display_errors(interpretation_alias, :base)
    end

    JSON.generate(data)
  end


  def display_expression_for_trix(interpretation)
    expression = interpretation.expression
    return expression if interpretation.interpretation_aliases.empty?

    ordered_aliases = interpretation.interpretation_aliases
                        .reject { |ialias| ialias._destroy }
                        .sort_by { |ialias| ialias.position_start }
    result = []
    expression.split('').each_with_index do |character, index|
      interpretation_alias = ordered_aliases.first
      if interpretation_alias.nil? || index < interpretation_alias.position_start
        result << character
      end
      if !interpretation_alias.nil? && index == interpretation_alias.position_end - 1
        text = expression[interpretation_alias.position_start..interpretation_alias.position_end-1]
        result << "<a href=\"#{alias_to_json_href(interpretation_alias)}\">#{text}</a>"
        ordered_aliases = ordered_aliases.drop(1)
      end
    end
    result.join('')
  end


  def display_expression(interpretation)
    expression = interpretation.expression

    result = []

    if interpretation.interpretation_aliases.count == 0
      result << expression
    else
      ordered_aliases = interpretation.interpretation_aliases.order(position_start: :asc)

      result << "<span class='interpretation-resume'>"
      expression.split('').each_with_index do |character, index|
        interpretation_alias = ordered_aliases.first
        if interpretation_alias.nil? || index < interpretation_alias.position_start
          result << character
        end
        if !interpretation_alias.nil? && index == interpretation_alias.position_end - 1
          if interpretation_alias.type_number?
            color = "black"
            title = "Number"
          elsif interpretation_alias.type_regex?
            color = "black"
            title = "Regex: #{interpretation_alias.reg_exp}"
          else
            title = interpretation_alias.interpretation_aliasable.slug
            color = interpretation_alias.interpretation_aliasable.color
          end
          css_class = "interpretation-resume__alias-#{color}"
          text = expression[interpretation_alias.position_start..interpretation_alias.position_end-1]
          result << "<span class='#{css_class}' title='#{title}'>#{text}</span>"
          ordered_aliases = ordered_aliases.drop(1)
        end
      end
      result << "</span>"
    end

    result << " <span class='merged-badges'>"
    result << " <span class='badge'>#{t('activerecord.attributes.interpretation.keep_order')}</span>"
    result << " <span class='badge badge--primary'><span class='icon icon--small icon--white'>"
    result << "#{interpretation.keep_order? ? icon_check : icon_close}</span></span></span>"

    proximity_label = "expression.proximity.#{interpretation.proximity}"
    result << " <span class='merged-badges'>"
    result << " <span class='badge'>#{t('expression.proximity.label')}</span>"
    result << " <span class='badge badge--primary'>#{t(proximity_label)}</span></span>"

    result << " <span class='merged-badges'>"
    result << " <span class='badge'>#{t('activerecord.attributes.interpretation.auto_solution_enabled')}</span>"
    result << " <span class='badge badge--primary'><span class='icon icon--small icon--white'>"
    result << "#{interpretation.auto_solution_enabled? ? icon_check : icon_close}</span></span></span>"

    result.join('').html_safe
  end

end
