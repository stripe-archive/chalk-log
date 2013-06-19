require 'socket'
require 'uri'
Gem.configuration
Gem.sources.each do |src|
  begin
    Socket.gethostbyname(URI.parse(src).host)
  rescue SocketError => e
    Bundler.ui.error("Unable to resolve gem source #{src}")
    raise e
  else
    source src
  end
end

gemspec
