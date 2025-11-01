class Epics::IndexPageComponent < BaseComponent
  def initialize(epics:)
    @epics = epics
  end
  
  private
  
  def status_badge_class(status)
    case status
    when 'pending'
      'bg-gray-100 text-gray-800 border-gray-200'
    when 'generating_spec'
      'bg-yellow-100 text-yellow-800 border-yellow-200'
    when 'running'
      'bg-blue-100 text-blue-800 border-blue-200'
    when 'paused'
      'bg-orange-100 text-orange-800 border-orange-200'
    when 'completed'
      'bg-green-100 text-green-800 border-green-200'
    when 'failed'
      'bg-red-100 text-red-800 border-red-200'
    else
      'bg-gray-100 text-gray-800 border-gray-200'
    end
  end
  
  def status_icon(status)
    case status
    when 'pending'
      '?'
    when 'generating_spec'
      '??'
    when 'running'
      '?'
    when 'paused'
      '?'
    when 'completed'
      '?'
    when 'failed'
      '?'
    else
      '?'
    end
  end
  
  def task_status_counts(epic)
    epic.tasks.reorder(nil).group(:status).count
  end
  
  def progress_percentage(epic)
    return 0 if epic.tasks.count.zero?
    
    completed = epic.tasks.completed.count
    total = epic.tasks.count
    (completed.to_f / total * 100).round
  end
end
