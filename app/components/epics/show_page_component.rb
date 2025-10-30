class Epics::ShowPageComponent < BaseComponent
  def initialize(epic:)
    @epic = epic
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
  
  def task_status_badge_class(status)
    case status
    when 'pending'
      'bg-gray-100 text-gray-700 border-gray-200'
    when 'running'
      'bg-blue-100 text-blue-700 border-blue-200'
    when 'pr_open'
      'bg-purple-100 text-purple-700 border-purple-200'
    when 'merging'
      'bg-yellow-100 text-yellow-700 border-yellow-200'
    when 'completed'
      'bg-green-100 text-green-700 border-green-200'
    when 'failed'
      'bg-red-100 text-red-700 border-red-200'
    else
      'bg-gray-100 text-gray-700 border-gray-200'
    end
  end
  
  def status_icon(status)
    case status
    when 'pending'
      '⏸'
    when 'generating_spec'
      '📝'
    when 'running'
      '⚡'
    when 'paused'
      '⏸'
    when 'completed'
      '✅'
    when 'failed'
      '❌'
    else
      '•'
    end
  end
end
