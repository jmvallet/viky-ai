class AgentSearch
  attr_reader :user_id, :options

  DEFAULT_CRITERIA = {
    'sort_by' => 'name',
    'filter_owner' => 'all',
    'filter_visibility' => 'all',
    'query' => ''
  }.with_indifferent_access.freeze

  def initialize(user, options = {})
    @user = user
    @options = build_options(user, options)
  end

  def self.keys
    ['query', 'filter_owner', 'filter_visibility', 'sort_by']
  end

  keys.each do |meth|
    define_method(meth) { options[meth.to_sym] }
  end

  def empty?
    @options[:query] == DEFAULT_CRITERIA[:query] &&
      @options[:sort_by] == DEFAULT_CRITERIA[:sort_by] &&
      @options[:filter_owner] == DEFAULT_CRITERIA[:filter_owner] &&
      @options[:filter_visibility] == DEFAULT_CRITERIA[:filter_visibility]
  end

  def save
    new_state = @user.ui_state.merge({
      agent_search: {
        query: @options[:query],
        sort_by: @options[:sort_by],
        filter_owner: @options[:filter_owner],
        filter_visibility: @options[:filter_visibility]
      }
    })
    @user.ui_state = new_state
    @user.save
  end

  private

    def build_options(user, http_options)
      default_options_for_user = (user.ui_state['agent_search'] || {}).with_indifferent_access
      cleaned_http_options = clean_options(http_options)
      final_options = DEFAULT_CRITERIA.merge(
        default_options_for_user
      ).merge(
        cleaned_http_options
      )
      final_options[:user_id] = user.id.strip
      final_options
    end

    def clean_options(options)
      (options || {}).transform_values do |v|
        v.respond_to?(:strip) ? v.strip : v
      end
    end
end
