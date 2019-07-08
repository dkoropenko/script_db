# frozen_string_literal: true

require 'mysql2'

class DatabaseOperation
  attr_reader :client

  def connect(username:, password:)
    @client = Mysql2::Client.new(
      host: host,
      username: username,
      password: password,
      database: database
    )
  end

  def add_colums
    client.query("ALTER TABLE #{table_name} ADD COLUMN clean_name VARCHAR(50), ADD COLUMN sentence VARCHAR(150);")
  end

  def condidate_names
    client.query("SELECT * FROM #{table_name};", symbolize_keys: true)
  end

  def save_results(hash:)
    return if hash[:clean_name].nil?

    client.query(
      "UPDATE #{table_name} SET
      clean_name = '#{escape_string(hash[:clean_name])}',
      sentence = '#{escape_string(hash[:sentence])}'
      WHERE id = #{hash[:id]};"
    )
  end

  private

  def host
    'db09'
  end

  def database
    'applicant_tests'
  end

  def table_name
    'hle_dev_test_dmitry_koropenko'
  end

  def escape_string(string)
    client.escape(string)
  end
end

class NamesReformat
  REGIONS = [
    'country',
    'state',
    'city',
    'village',
    'community',
    'township',
    'park district',
    'township',
    'highway'
  ].freeze

  attr_reader :hash

  def init_hash(hash:)
    @hash = hash
  end

  def prepare_clear_names
    hash.each do |row|
      @name = row[:candidate_office_name]

      next if @name.size.zero?

      step_1
      step_2
      step_3
      step_4
      step_5

      row[:clean_name] = @name
      row[:sentence] = "The candidate is running for the #{@name} office."
    end
  end

  private

  def step_1
    @name.gsub!(/(\A|\s)Twp(\z|\s)/, ' Township ')
    @name.gsub!(/(\A|\s)Hwy(\z|\s)/, ' Highway ')
  end

  def step_2
    splitted = @name.split('/')

    region = splitted.first.split(' ').shift.downcase

    if REGIONS.include?(region) && splitted.last.split(' ').last.downcase == region
      splitted[0] = splitted.first.downcase.gsub(region, '')
      @name = clean_string("#{splitted.pop} #{splitted.join(' and ').downcase}")
    end
  end

  def step_3
    splitted = @name.split('/')

    return if splitted.size != 2

    first_part, second_part = splitted

    first_part = first_part.split(' ')
    first_word = first_part.pop.downcase

    second_part = second_part.split(' ')
    second_word = second_part.shift

    @name = clean_string("#{join_array(first_part)} #{second_word} #{first_word} #{join_array(second_part)}")
  end

  def step_4
    return unless @name.include?(',')

    first_part, second_part = @name.split(',')
    @name = clean_string("#{first_part} (#{join_array(second_part)})")
  end

  def step_5
    return unless @name.include?('.')

    @name = @name.downcase.gsub('.', '')
  end

  def clean_string(string)
    string.strip.gsub(/\s+/, ' ')
  end

  def join_array(object)
    object.is_a?(Array) ? object.join(' ') : object
  end
end

database = DatabaseOperation.new
names_format = NamesReformat.new

puts '
    Hello
    Script help. Use command in it\'s order:
    - connect               Connected to database. Use it once before other commands
    - add_colums            Added columns "clean_name" and "sentence" to database. Use it once
    - get_names             Get names from table. If results changed please repeat
    - prepare_clear_names   Prepare clear names. If you want you can display result before save.
    - save_clear_names      Save result in table.
    - exit                  exit from script
    '

loop do
  input = gets.chomp

  case input
  when /\Aconnect\z/i
    puts 'Input DB username:'
    username = gets.chomp

    puts 'Input DB password:'
    password = gets.chomp

    database.connect(username: username, password: password)
    puts 'Connection OK.'

  when /\Aadd_columns\z/i
    database.add_colums
    puts 'Column added'

  when /\Aget_names\z/i
    condidate_names = database.condidate_names
    names_format.init_hash(hash: condidate_names)

    puts "Candidate names count: #{condidate_names.size}"
    condidate_names.each { |row| p row }

  when /\Aprepare_clear_names\z/i
    names_format.prepare_clear_names

    puts 'Clear names completed'

  when /\Asave_clear_names\z/i
    names_format.hash.each { |row| database.save_results(hash: row) }

    puts 'Result saved'

  when /\Aexit\z/i
    abort('Bye')
  else puts 'Invalid command'
  end
end
