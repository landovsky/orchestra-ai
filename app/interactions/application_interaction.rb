# frozen_string_literal: true

# ApplicationInteraction serves as the base class for all interactions in the application.
# It inherits from ActiveInteraction::Base and provides a common foundation for
# implementing business logic in a structured, testable way.
#
# Example usage:
#   class MyInteraction < ApplicationInteraction
#     string :name
#     integer :age
#
#     def execute
#       # Your business logic here
#     end
#   end
class ApplicationInteraction < ActiveInteraction::Base
  # Add any common interaction functionality here
  # For example, common validations, callbacks, or helper methods
end
