module Critic::Fake
  Dir[File.expand_path('../fake/*.rb', __FILE__)].each do |file|
    require_relative(file)
  end
end
