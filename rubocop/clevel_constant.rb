require 'rubocop'

module PrisonGuard
  # Ensure clevels are set using the Chalk::Log constants
  class CLevelConstant < RuboCop::Cop::Cop

    LOG_METHODS = %w{debug info warn error}

    VALID_CLEVELS_SEXPR = [
      s(:const,
        s(:const,
          s(:const,
            s(:const, nil, :Chalk), :Log), :CLevels), :Sheddable),

      s(:const,
        s(:const,
          s(:const,
            s(:const, nil, :Chalk), :Log), :CLevels), :SheddablePlus),

      s(:const,
        s(:const,
          s(:const,
            s(:const, nil, :Chalk), :Log), :CLevels), :Critical),

      s(:const,
        s(:const,
          s(:const,
            s(:const, nil, :Chalk), :Log), :CLevels), :CriticalPlus),
    ]

    def investigate(processed_source)
      @file_path = processed_source.buffer.name
      @skip_file = @file_path.include?('/test/')
    end

    def on_send(node)
      return if @skip_file
      receiver, method_name, _args, hashargs = *node

      return unless receiver
      return unless receiver.children

      return if !LOG_METHODS.include?(method_name.to_s)
      return unless hashargs
      return if hashargs.type != :hash

      hashargs.children.map do |pair|
        next if pair.children && pair.children[0].to_a[0] != :clevel

        if pair.children[1].type != :const
          add_offense(node, :expression, "Non-constant clevel specified: #{pair.children[1]}. Use Chalk::Log::Clevels::Sheddable")
        end

        if !VALID_CLEVELS_SEXPR.include?(pair.children[1])
          add_offense(node, :expression, "Invalid clevel: #{pair.children[1]}")
        end
      end
    end
  end
end
