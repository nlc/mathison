require 'pp'

class EmbeddedString
  attr_accessor :string
  attr_accessor :total_len
  attr_accessor :zero_point
  attr_accessor :mutated_range

  def initialize(string)
    len = string.length
    @string = [(' ' * len), string, (' ' * len)].join(' ')
    @zero_point = len + 1
    @total_len = @string.length
    @mutated_range = (@zero_point..(@zero_point + len))
  end

  def get(index)
    true_index = index + @zero_point
    if(true_index < 0 || true_index > @total_len)
      ' '
    else
      @string[true_index]
    end
  end

  def set(index, value)
    true_index = index + @zero_point
    while(true_index < 0 || true_index > @total_len)
      len = @string.length
      @string = [(' ' * len), string, (' ' * len)].join(' ')
      @zero_point += len + 1
      @total_len = @string.length
      true_index = index + @zero_point
    end

    @string[true_index] = value
    if(true_index < @mutated_range.min)
      @mutated_range = (true_index..(@mutated_range.max))
    end
    if(true_index > @mutated_range.max)
      @mutated_range = ((@mutated_range.min)..true_index)
    end
  end

  def stringify
    @string[@mutated_range]
  end
end

class TuringMachine
  attr_accessor :state
  attr_accessor :states
  attr_accessor :tape
  attr_accessor :head_index
  attr_accessor :halted

  def perror(msg, lineno = nil)
    if lineno.nil?
      raise "TM error: #{msg}"
    else
      raise "TM error on line #{lineno}: #{msg}"
    end
  end

  def pwarning(msg, lineno = nil)
    if lineno.nil?
      STDERR.puts "\033[1mTM warning\033[0m: #{msg}"
    else
      STDERR.puts "\033[1mTM warning\033[0m on line #{lineno}: #{msg}"
    end
  end

  def initialize(fname)
    @halted = false
    @states = { }
    state_index = nil

    File.readlines(fname).each_with_index do |line, i|
      case line
      when /^ *#/ # comment
        # ignore, next line
      when /^:(.*):\s*$/
        state_index = $1
        perror('illegal use of reserved state H', i + 1) if state_index =~ /^H$/
        @state = state_index if @states.empty?
      when / *([^\/]+)\/([^\/]+)\/([^\/]+)\/([^\/]+)/
        pattern = /#{$1}/
        replacement = $2
        movement = $3
        newstate = $4.chomp

        perror('tried to set rule outside state context', i + 1) unless state_index

        perror("illegal movement instruction \"#{movement}\"", i + 1) unless movement =~ /[LNR]/

        @states[state_index] = {} unless @states[state_index]
        @states[state_index][pattern] = { replacement: replacement,
                                          movement: movement,
                                          newstate: newstate }
      else
        perror("failed to parse #{line.dump}", i + 1)
      end
    end

    legal_states = @states.keys.uniq
    possible_states = @states.map { |_key, state| state.map { |_symbol, transition| transition[:newstate] } }.flatten.uniq
    undefined_states = possible_states - legal_states

    undefined_without_halt = undefined_states - ['H']

    if undefined_without_halt.any?
      pwarning("defined transitions to undefined states (#{undefined_without_halt.map { |state_name| "\"#{state_name}\"" } .join(', ')})")
    end
  end

  def init_tape(tape, head_index)
    @tape = EmbeddedString.new(tape)
    @head_index = head_index
  end

  def halt
    @state = 'H'
    @halted = true
  end

  def iterate
    symbol = @tape.get(@head_index)
    has_matched = false

    halt if @state =~ /^H$/
    perror("entered undefined state \"#{@state}\"") if @states[@state].nil?

    @states[@state].each do |pattern, rule|
      if(symbol =~ pattern)
        has_matched = true
        unless rule[:replacement] =~ /^&$/
          @tape.set(@head_index, rule[:replacement])
        end

        if rule[:movement] =~ /L/
          @head_index -= 1
        elsif rule[:movement] =~ /R/
          @head_index += 1
        elsif rule[:movement] =~ /N/
        else
          raise 'TM runtime error'
        end

        if rule[:movement] =~ /N/ && @state == rule[:newstate] # Treat no motion, no state change as a halt
          halt
        else
          @state = rule[:newstate]
        end
        break
      end
    end
    perror("could not find matching rule for symbol #{symbol.dump}") unless has_matched
  end
end

tm = TuringMachine.new('copier.tur')
tm.init_tape(" -#{(1..10).map{%w[0 1].sample}.join('')}- ", 1)

# tm = TuringMachine.new('beaver_4state.tur')
# tm.init_tape('0' * 32, 15)

# pp tm.states
tempstr = tm.tape.stringify + ' '
# tempstr.insert(tm.head_index, "\e[7m")
# tempstr.insert(tm.head_index + 5, "\e[0m")
tempstr[tm.head_index] = "\e[7m#{tempstr[tm.head_index]}\e[0m"
puts "\e[2K#{tempstr}"

until tm.state =~ /^H$/
  tm.iterate

  tempstr = tm.tape.stringify + ' '
  # tempstr.insert(tm.head_index, "\e[7m")
  # tempstr.insert(tm.head_index + 5, "\e[0m")
  tempstr[tm.head_index] = "\e[7m#{tempstr[tm.head_index]}\e[0m"
  puts "\e[2K#{tempstr}"
end

# test
