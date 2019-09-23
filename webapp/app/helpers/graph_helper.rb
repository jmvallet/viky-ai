module GraphHelper

  def prepare_requests_data(processed_requests, rejected_requests, from, to)
    JSON.generate(
      from: from,
      to: to,
      data: [
      {
        name: 'Processed requests',
        data: processed_requests.map do |requests|
          [requests['key'], requests['doc_count']]
        end
      },
      {
        name: 'Rejected requests',
        data: rejected_requests.map do |requests|
          [requests['key'], requests['doc_count']]
        end
      }
    ]).html_safe
  end

  def prepare_expressions_data(user)
    expressions = user.expressions_count(true)
    quota = Quota.expressions_limit
    total = expressions[:entities] + expressions[:formulations]
    JSON.generate(
      data: [expressions[:formulations], expressions[:entities], quota - total],
      label: ['Formulations', 'Entities', 'Remaining'],
      total: total,
      quota: quota
    ).html_safe
  end
end
