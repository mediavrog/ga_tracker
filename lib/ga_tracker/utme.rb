class GATracker::UTME

  def initialize
    @custom_variables = CustomVariables.new
  end

  def set_event(category, action, label=nil, value=nil)
    @event = Event.new(category, action, label, value)
    self
  end

  def set_custom_variable(slot, name, value, scope=nil)
    @custom_variables.set_custom_variable(slot, CustomVariable.new(name, value, scope))
    self
  end

  def unset_custom_variable(slot)
    @custom_variables.unset_custom_variable(slot)
    self
  end

  def to_s
    @event.to_s + @custom_variables.to_s
  end

  private

  Event = Struct.new(:category, :action, :opt_label, :opt_value) do
    def to_s
      output = "5(#{category}*#{action}"
      output += "*#{opt_label}" if opt_label
      output += ")"
      output += "(#{opt_value})" if opt_value
      output
    end
  end

  CustomVariable = Struct.new(:name, :value, :opt_scope) do
    def to_s
      bang = "#{slot != 1 ? "#{slot}!" : ''}"
      output = "8(#{bang}#{name})9(#{bang}#{value})"
      output += "11(#{bang}#{opt_scope})" if opt_scope
      output
    end
  end

  class CustomVariables

    @@valid_keys = 1..5

    def initialize
      @contents = { }
    end

    def set_custom_variable(slot, custom_variable)
      return false if not @@valid_keys.include?(slot)
      @contents[slot] = custom_variable
    end

    def unset_custom_variable(slot)
      return false if not @@valid_keys.include?(slot)
      @contents.delete(slot)
    end

    # follows google custom variable format
    # best explained by examples
    #
    # 1)
    # pageTracker._setCustomVar(1,"foo", "val", 1)
    # ==> 8(foo)9(bar)11(1)
    #
    # 2)
    # pageTracker._setCustomVar(1,"foo", "val", 1)
    # pageTracker._setCustomVar(2,"bar", "vok", 3)
    # ==> 8(foo*bar)9(val*vok)11(1*3)
    #
    # 3)
    # pageTracker._setCustomVar(1,"foo", "val", 1)
    # pageTracker._setCustomVar(2,"bar", "vok", 3)
    # pageTracker._setCustomVar(4,"baz", "vol", 1)
    # ==> 8(foo*bar*4!baz)9(val*vak*4!vol)11(1*3*4!1)
    #
    # 4)
    # pageTracker._setCustomVar(4,"foo", "bar", 1)
    # ==> 8(4!foo)9(4!bar)11(4!1)
    #
    def to_s
      return '' if @contents.empty?

      ordered_keys = @contents.keys.sort
      names = values = scopes = ''

      ordered_keys.each do |slot|
        custom_variable = @contents[slot]
        predecessor = @contents[slot-1]

        has_predecessor = !!predecessor
        has_scoped_predecessor = !!predecessor.try(:opt_scope)

        star = names.empty? ? '' : '*'
        bang = (slot == 1 || has_predecessor) ? '' : "#{slot}!"

        scope_star = scopes.empty? ? '' : '*'
        scope_bang = (slot == 1 || has_scoped_predecessor) ? '' : "#{slot}!"

        names += "#{star}#{bang}#{custom_variable.name}"
        values += "#{star}#{bang}#{custom_variable.value}"
        scopes += "#{scope_star}#{scope_bang}#{custom_variable.opt_scope}" if custom_variable.opt_scope
      end

      output = "8(#{names})9(#{values})"
      output += "11(#{scopes})" if not scopes.empty?
      output
    end

  end

end