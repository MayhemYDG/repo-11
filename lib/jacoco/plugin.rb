# frozen_string_literal: true

require 'jacoco/sax_parser'

module Danger
  # Verify code coverage inside your projects
  # This is done using the jacoco output
  # Results are passed out as a table in markdown
  #
  # @example Verify coverage
  #          jacoco.minimum_project_coverage_percentage = 50
  #
  # @example Verify coverage per package
  #          jacoco.minimum_package_coverage_map = { # optional (default is empty)
  #           'com/package/' => 55,
  #           'com/package/more/specific/' => 15
  #          }
  #
  # @see  Anton Malinskiy/danger-jacoco
  # @tags jacoco, coverage, java, android, kotlin
  #
  class DangerJacoco < Plugin # rubocop:disable Metrics/ClassLength
    attr_accessor :minimum_project_coverage_percentage, :minimum_class_coverage_percentage,
                  :minimum_composable_class_coverage_percentage, :only_check_new_files, :files_extension,
                  :minimum_package_coverage_map, :minimum_class_coverage_map, :fail_no_coverage_data_found,
                  :title, :class_column_title, :subtitle_success, :subtitle_failure

    # Initialize the plugin with configured parameters or defaults
    def setup
      setup_minimum_coverages
      setup_texts
      @only_check_new_files = false unless only_check_new_files
      @files_extension = ['.kt', '.java'] unless files_extension
    end

    # Initialize the plugin with configured optional texts
    def setup_texts
      @title = 'JaCoCo' unless title
      @class_column_title = 'Class' unless class_column_title
      @subtitle_success = 'All classes meet coverage requirement. Well done! :white_check_mark:' unless subtitle_success
      @subtitle_failure = 'There are classes that do not meet coverage requirement :warning:' unless subtitle_failure
    end

    # Initialize the plugin with configured coverage minimum parameters or defaults
    def setup_minimum_coverages
      @minimum_project_coverage_percentage = 0 unless minimum_project_coverage_percentage
      @minimum_class_coverage_percentage = 0 unless minimum_class_coverage_percentage
      @minimum_composable_class_coverage_percentage = 0 unless minimum_composable_class_coverage_percentage
      @minimum_package_coverage_map = {} unless minimum_package_coverage_map
      @minimum_class_coverage_map = {} unless minimum_class_coverage_map
    end

    # Parses the xml output of jacoco to Ruby model classes
    # This is slow since it's basically DOM parsing
    #
    # @path path to the xml output of jacoco
    #
    def parse(path)
      Jacoco::DOMParser.read_path(path)
    end

    # This is a fast report based on SAX parser
    #
    # @path path to the xml output of jacoco
    # @report_url URL where html report hosted
    # @delimiter git.modified_files returns full paths to the
    # changed files. We need to get the class from this path to check the
    # Jacoco report,
    #
    # e.g. src/java/com/example/SomeJavaClass.java -> com/example/SomeJavaClass
    # e.g. src/kotlin/com/example/SomeKotlinClass.kt -> com/example/SomeKotlinClass
    #
    # The default value supposes that you're using gradle structure,
    # that is your path to source files is something like
    #
    # Java => blah/blah/java/slashed_package/Source.java
    # Kotlin => blah/blah/kotlin/slashed_package/Source.kt
    #
    # rubocop:disable Style/AbcSize
    def report(path, report_url = '', delimiter = %r{/java/|/kotlin/}, fail_no_coverage_data_found: true)
      @fail_no_coverage_data_found = fail_no_coverage_data_found

      setup
      class_to_file_path_hash = classes(delimiter)
      classnames = class_to_file_path_hash.keys

      parser = Jacoco::SAXParser.new(classnames)
      Nokogiri::XML::SAX::Parser.new(parser).parse(File.open(path))

      total_covered = total_coverage(path)

      header = "### #{title} Code Coverage #{total_covered[:covered]}% #{total_covered[:status]}\n"
      report_markdown = header
      report_markdown += "| #{class_column_title} | Covered | Required | Status |\n"
      report_markdown += "|:---|:---:|:---:|:---:|\n"
      class_coverage_above_minimum = markdown_class(parser, report_markdown, report_url, class_to_file_path_hash)
      subtitle = class_coverage_above_minimum ? subtitle_success : subtitle_failure
      report_markdown.insert(header.length, "#### #{subtitle}\n")
      markdown(report_markdown)

      report_fails(class_coverage_above_minimum, total_covered)
    end
    # rubocop:enable Style/AbcSize

    # Select either only added files or modified and added files in this PR,
    # depending on "only_check_new_files" attribute
    def classes(delimiter)
      git = @dangerfile.git
      affected_files = only_check_new_files ? git.added_files : git.added_files + git.modified_files
      class_to_file_path_hash = {}
      affected_files.select { |file| files_extension.reduce(false) { |state, el| state || file.end_with?(el) } }
                    .each do |file| # "src/java/com/example/CachedRepository.java"
                      classname = file.split('.').first.split(delimiter)[1] # "com/example/CachedRepository"
                      class_to_file_path_hash[classname] = file
                    end
      class_to_file_path_hash
    end

    # It returns a specific class code coverage and an emoji status as well
    def report_class(jacoco_class, file_path)
      report_result = {
        covered: 'No coverage data found : -',
        status: ':black_joker:',
        required_coverage_percentage: 'No coverage data found : -'
      }

      counter = coverage_counter(jacoco_class)
      unless counter.nil?
        coverage = (counter.covered.fdiv(counter.covered + counter.missed) * 100).floor
        required_coverage = required_class_coverage(jacoco_class, file_path)
        status = coverage_status(coverage, required_coverage)

        report_result = {
          covered: coverage,
          status: status,
          required_coverage_percentage: required_coverage
        }
      end

      report_result
    end

    # Determines the required coverage for the class
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    def required_class_coverage(jacoco_class, file_path)
      key = minimum_class_coverage_map.keys.detect { |k| jacoco_class.name.match(k) } || jacoco_class.name
      required_coverage = minimum_class_coverage_map[key]
      includes_composables = File.read(file_path).include? '@Composable' if File.exist?(file_path)
      required_coverage = minimum_composable_class_coverage_percentage if required_coverage.nil? && includes_composables
      required_coverage = package_coverage(jacoco_class.name) if required_coverage.nil?
      required_coverage = minimum_class_coverage_percentage if required_coverage.nil?
      required_coverage
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity

    # it returns the most suitable coverage by package name to class or nil
    def package_coverage(class_name)
      path = class_name
      package_parts = class_name.split('/')
      package_parts.reverse_each do |item|
        size = item.size
        path = path[0...-size]
        coverage = minimum_package_coverage_map[path]
        path = path[0...-1] unless path.empty?
        return coverage unless coverage.nil?
      end
      nil
    end

    # it returns an emoji for coverage status
    def coverage_status(coverage, minimum_percentage)
      if coverage < (minimum_percentage / 2) then ':skull:'
      elsif coverage < minimum_percentage then ':warning:'
      else
        ':white_check_mark:'
      end
    end

    # It returns total of project code coverage and an emoji status as well
    def total_coverage(report_path)
      jacoco_report = Nokogiri::XML(File.open(report_path))

      report = jacoco_report.xpath('report/counter').select { |item| item['type'] == 'INSTRUCTION' }
      missed_instructions = report.first['missed'].to_f
      covered_instructions = report.first['covered'].to_f
      total_instructions = missed_instructions + covered_instructions
      covered_percentage = (covered_instructions * 100 / total_instructions).round(2)
      coverage_status = coverage_status(covered_percentage, minimum_project_coverage_percentage)

      {
        covered: covered_percentage,
        status: coverage_status
      }
    end

    private

    def coverage_counter(jacoco_class)
      all_class_counters = jacoco_class.counters
      counter = class_counter(all_class_counters)

      if counter.nil?
        no_coverage_data_found_message = "No coverage data found for #{jacoco_class.name}"

        raise no_coverage_data_found_message if @fail_no_coverage_data_found.instance_of?(TrueClass)

        warn no_coverage_data_found_message
      end

      counter
    end

    def class_counter(all_class_counters)
      instruction_counter = all_class_counters.detect { |e| e.type.eql? 'INSTRUCTION' }
      branch_counter = all_class_counters.detect { |e| e.type.eql? 'BRANCH' }
      line_counter = all_class_counters.detect { |e| e.type.eql? 'LINE' }
      if !instruction_counter.nil?
        instruction_counter
      elsif !branch_counter.nil?
        branch_counter
      else
        line_counter
      end
    end

    # rubocop:disable Style/SignalException
    def report_fails(class_coverage_above_minimum, total_covered)
      if total_covered[:covered] < minimum_project_coverage_percentage
        # fail danger if total coverage is smaller than minimum_project_coverage_percentage
        covered = total_covered[:covered]
        fail("Total coverage of #{covered}%. Improve this to at least #{minimum_project_coverage_percentage}%")
      end

      return if class_coverage_above_minimum

      fail("Class coverage is below minimum. Improve to at least #{minimum_class_coverage_percentage}%")
    end
    # rubocop:enable Style/SignalException

    def markdown_class(parser, report_markdown, report_url, class_to_file_path_hash)
      class_coverage_above_minimum = true
      parser.classes.each do |jacoco_class| # Check metrics for each classes
        file_path = class_to_file_path_hash[jacoco_class.name]
        rp = report_class(jacoco_class, file_path)
        rl = report_link(jacoco_class.name, report_url)
        ln = "| #{rl} | #{rp[:covered]}% | #{rp[:required_coverage_percentage]}% | #{rp[:status]} |\n"
        report_markdown << ln

        class_coverage_above_minimum &&= rp[:covered] >= rp[:required_coverage_percentage]
      end

      class_coverage_above_minimum
    end

    def report_link(class_name, report_url)
      if report_url.empty?
        "`#{class_name}`"
      else
        report_filepath = "#{class_name.gsub(%r{/(?=[^/]*/.)}, '.')}.html"
        "[`#{class_name}`](#{report_url + report_filepath})"
      end
    end
  end
end
