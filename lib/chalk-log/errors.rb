module Chalk::Log
  # Base error class
  class Error < StandardError; end
  # Thrown when you call a layout with the wrong arguments. (It gets
  # swallowed and printed by the fault handling in layout.rb, though.)
  class InvalidArguments < Error; end
end
