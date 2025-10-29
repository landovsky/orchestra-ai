module ApplicationHelper
  def status_color(status)
    case status.to_s
    when 'pending'
      'gray'
    when 'generating_spec'
      'blue'
    when 'running'
      'yellow'
    when 'pr_open'
      'purple'
    when 'merging'
      'indigo'
    when 'completed'
      'green'
    when 'paused'
      'orange'
    when 'failed', 'error'
      'red'
    else
      'gray'
    end
  end
end
