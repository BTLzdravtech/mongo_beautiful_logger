require "mongo_beautiful_logger/colors"
require "mongo_beautiful_logger/mongo_actions"
require "logger"

class MongoBeautifulLogger
  include MongoActions
  include Colors

  def initialize(*targets)
    nil_targets_error if targets.empty?
    @targets = targets.map do |t| 
      logger = Logger.new(t)
      format! logger
      logger
    end
  end

  private

  def nil_targets_error
    raise ArgumentError.new "wrong number of arguments (given 0, expected at least 1)"
  end

  # default logger format, removes prompt of:
  # +d, [2020-06-20 14:02:29#17329] INFO -- MONGODB:+
  def format!(logger)
    logger.formatter = proc { |severity, datetime, progname, msg| "#{msg}" }
  end

  # define custom logger methods
  # formats log message and then sends message back to the logger instance
  %w(debug info warn error fatal unknown).each do |level|
    class_eval <<-RUBY
      def #{level}(msg = nil, &block)
        return if unnecessary?(msg)
        msg = format_log(msg)
        @targets.each { |t| t.#{level}(msg, &block) }; nil
      end
    RUBY
  end

  # checks if a message if a message is included in the +UNNECESSARY+ array constant
  def unnecessary?(msg)
    UNNECESSARY.any? { |s| msg.downcase.include? s }
  end

  # takes a log message and returns the message formatted
  def format_log(msg)
    msg = colorize_log(msg)
    # msg = remove_prefix(msg)
    "  #{msg}\n"
  end

  # colorize messages that are specified in ACTIONS constant
  def colorize_log(msg)
    ACTIONS.each { |a| msg = color(msg, a[:color]) if msg.downcase.include?(a[:match]) }
    return msg
  end

  # remove prefix defined in +PREFIX_REGEX+ from message
  def remove_prefix(msg)
    msg.sub(PREFIX_REGEX, "|")
  end

  # send all other methods back to logger instance
  def method_missing(method, *args, &block)
    @targets.each { |t| t.send(method, *args, &block) }
  end

  # set color based one the defined constants. 
  # If a third option is set to +true+, the string will be made bold. 
  # CLEAR to the is automatically appended to the string for reset
  def color(text, color, bold = false)
    bold = bold ? BOLD : ""
    "#{bold}#{color}#{text}#{CLEAR}"
  end
end
