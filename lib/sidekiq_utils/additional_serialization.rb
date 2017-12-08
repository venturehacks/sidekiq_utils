module SidekiqUtils
  module AdditionalSerialization
    def self.wrap_argument(arg)
      if arg.is_a?(Array)
        arg.map {|a| wrap_argument(a) }
      elsif arg.is_a?(Hash)
        wrapped = arg.each_with_object({}) do |(key, value), hash|
          hash[key.to_s] = wrap_argument(value)
        end
        symbol_keys = arg.each_key.grep(Symbol).map(&:to_s)
        wrapped['_al_aj_symbol_keys'] = symbol_keys if symbol_keys.present?
        if arg.is_a?(ActiveSupport::HashWithIndifferentAccess)
          wrapped['_al_aj_indifferent_access'] = true
        end
        wrapped
      elsif arg.is_a?(Symbol)
        { '_al_aj_wrapped' => 'symbol', 'value' => arg.to_s }
      elsif arg.is_a?(Class)
        { '_al_aj_wrapped' => 'class', 'value' => arg.name }
      else
        arg
      end
    end

    def self.unwrap_argument(arg)
      if arg.is_a?(Hash) && arg['_al_aj_wrapped'].present?
        case arg['_al_aj_wrapped']
        when 'symbol'
          arg['value'].to_sym
        when 'class'
          arg['value'].constantize
        else
          fail("Unknown wrapped value: #{arg['_al_aj_wrapped']}")
        end
      elsif arg.is_a?(Hash)
        # make sure that we don't accidentally mess with the argument here,
        # rather the caller should be responsible for actually replacing values
        arg = arg.deep_dup

        symbol_keys = arg.delete('_al_aj_symbol_keys') || []
        unwrapped = arg.each_with_object({}) do |(key, value), hash|
          key = key.to_sym if symbol_keys.include?(key)
          hash[key] = unwrap_argument(value)
        end
        if unwrapped.delete('_al_aj_indifferent_access')
          unwrapped = unwrapped.with_indifferent_access
        end
        unwrapped
      elsif arg.is_a?(Array)
        arg.map {|a| unwrap_argument(a) }
      else
        arg
      end
    end
  end
end
