class BaseComponent < ViewComponent::Base
  # Base component for all ViewComponents
  # Provides common functionality and helpers
  
  private
  
  # Helper to generate data-test attributes for easier testing
  def test_id(id)
    { data: { test: id } }
  end
end
