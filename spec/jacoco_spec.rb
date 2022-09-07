# frozen_string_literal: true

# rubocop:disable Layout/LineLength
# rubocop:disable Metrics/ModuleLength
# rubocop:disable Metrics/BlockLength

require File.expand_path('spec_helper', __dir__)

module Danger
  describe Danger::DangerJacoco do
    it 'should be a plugin' do
      expect(Danger::DangerJacoco.new(nil)).to be_a Danger::Plugin
    end

    #
    # You should test your custom attributes and methods here
    #
    describe 'with Dangerfile' do
      before do
        @dangerfile = testing_dangerfile
        @my_plugin = @dangerfile.jacoco

        modified_files = ['src/java/com/example/CachedRepository.java']
        added_files = ['src/java/io/sample/UseCase.java']

        allow(@dangerfile.git).to receive(:modified_files).and_return(modified_files)
        allow(@dangerfile.git).to receive(:added_files).and_return(added_files)
      end

      it :report do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.minimum_class_coverage_map = { 'com/example/CachedRepository' => 100 }

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:errors]).to eq(['Total coverage of 32.9%. Improve this to at least 50%',
                                                          'Class coverage is below minimum. Improve to at least 0%'])
        expect(@dangerfile.status_report[:markdowns][0].message).to include('### JaCoCo Code Coverage 32.9% :warning:')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('| Class | Covered | Required | Status |')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('|:---|:---:|:---:|:---:|')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 100% | :warning: |')
      end

      it 'test regex class coverage' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.minimum_class_coverage_map = { '.*Repository' => 60 }

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 60% | :warning: |')
      end

      it 'test with package coverage' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.minimum_package_coverage_map = { 'com/example/' => 70 }

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 70% | :warning: |')
      end

      it 'test with bigger overlapped package coverage' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.minimum_package_coverage_map = {
          'com/example/' => 70,
          'com/' => 90
        }

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 70% | :warning: |')
      end

      it 'test with lower overlapped package coverage' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.minimum_package_coverage_map = {
          'com/example/' => 77,
          'com/' => 30
        }

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 77% | :warning: |')
      end

      it 'test with overlapped package coverage and bigger class coverage' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.minimum_package_coverage_map = {
          'com/example/' => 77,
          'com/' => 30
        }
        @my_plugin.minimum_class_coverage_map = { 'com/example/CachedRepository' => 100 }

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 100% | :warning: |')
      end

      it 'test with overlapped package coverage and lower class coverage' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.minimum_package_coverage_map = {
          'com/example/' => 90,
          'com/' => 85
        }
        @my_plugin.minimum_class_coverage_map = { 'com/example/CachedRepository' => 80 }

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 80% | :warning: |')
      end

      it 'checks modified files when "only_check_new_files" attribute is false' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_c.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.only_check_new_files = false

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('### JaCoCo Code Coverage 55.59% :white_check_mark:')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('| Class | Covered | Required | Status |')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('|:---|:---:|:---:|:---:|')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 0% | :white_check_mark: |')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `io/sample/UseCase` | 66% | 0% | :white_check_mark: |')
      end

      it 'defaults "only_check_new_files" attribute to false' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_c.xml"

        @my_plugin.minimum_project_coverage_percentage = 50

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 0% | :white_check_mark: |')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `io/sample/UseCase` | 66% | 0% | :white_check_mark: |')
      end

      it 'does _not_ check modified files when "only_check_new_files" attribute is true' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_c.xml"

        @my_plugin.minimum_project_coverage_percentage = 50
        @my_plugin.minimum_class_coverage_percentage = 70
        @my_plugin.only_check_new_files = true

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('### JaCoCo Code Coverage 55.59% :white_check_mark:')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('| Class | Covered | Required | Status |')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('|:---|:---:|:---:|:---:|')
        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `io/sample/UseCase` | 66% | 70% | :warning: |')
        expect(@dangerfile.status_report[:markdowns][0].message).not_to include('com/example/CachedRepository')
      end

      it 'adds a link to report' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_class_coverage_percentage = 80
        @my_plugin.minimum_project_coverage_percentage = 50

        @my_plugin.report(path_a, 'http://test.com/')

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| [`com/example/CachedRepository`](http://test.com/com.example/CachedRepository.html) | 50% | 80% | :warning: |')
      end

      it 'When option "fail_no_coverage_data_found" is set to optionally fail, it doesn\'t fail the execution' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_class_coverage_percentage = 80
        @my_plugin.minimum_project_coverage_percentage = 50

        expect { @my_plugin.report(path_a, fail_no_coverage_data_found: true) }.to_not raise_error(RuntimeError)
      end

      it 'When option "fail_no_coverage_data_found" is not set, the execution fails on empty data' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_b.xml"

        @my_plugin.minimum_class_coverage_percentage = 80
        @my_plugin.minimum_project_coverage_percentage = 50

        expect { @my_plugin.report path_a }.to raise_error(RuntimeError)
      end

      it 'When option "fail_no_coverage_data_found" is set to optionally fail, the execution fails on empty data' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_b.xml"

        @my_plugin.minimum_class_coverage_percentage = 80
        @my_plugin.minimum_project_coverage_percentage = 50

        expect { @my_plugin.report path_a, fail_no_coverage_data_found: true }.to raise_error(RuntimeError)
      end

      it 'When option "fail_no_coverage_data_found" is set to optionally warn (not fail), the execution doesn\'t fail on empty data' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_b.xml"

        @my_plugin.minimum_class_coverage_percentage = 80
        @my_plugin.minimum_project_coverage_percentage = 50

        expect { @my_plugin.report path_a, fail_no_coverage_data_found: false }.to_not raise_error(RuntimeError)
      end

      it 'prints default success subtitle' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 30
        @my_plugin.minimum_class_coverage_percentage = 40

        @my_plugin.report path_a

        expected = "### JaCoCo Code Coverage 32.9% :white_check_mark:\n"
        expected += "#### All classes meet coverage requirement. Well done! :white_check_mark:\n"
        expected += "| Class | Covered | Required | Status |\n"
        expected += "|:---|:---:|:---:|:---:|\n"
        expected += "| `com/example/CachedRepository` | 50% | 40% | :white_check_mark: |\n"
        expect(@dangerfile.status_report[:markdowns][0].message).to include(expected)
      end

      it 'prints default failure subtitle' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 30
        @my_plugin.minimum_class_coverage_percentage = 60

        @my_plugin.report path_a

        expected = "### JaCoCo Code Coverage 32.9% :white_check_mark:\n"
        expected += "#### There are classes that do not meet coverage requirement :warning:\n"
        expected += "| Class | Covered | Required | Status |\n"
        expected += "|:---|:---:|:---:|:---:|\n"
        expected += "| `com/example/CachedRepository` | 50% | 60% | :warning: |\n"
        expect(@dangerfile.status_report[:markdowns][0].message).to include(expected)
      end

      it 'prints custom success subtitle' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 30
        @my_plugin.minimum_class_coverage_percentage = 40
        @my_plugin.subtitle_success = 'You rock! 🔥'

        @my_plugin.report path_a

        expected = "### JaCoCo Code Coverage 32.9% :white_check_mark:\n"
        expected += "#### You rock! 🔥\n"
        expected += "| Class | Covered | Required | Status |\n"
        expected += "|:---|:---:|:---:|:---:|\n"
        expected += "| `com/example/CachedRepository` | 50% | 40% | :white_check_mark: |\n"
        expect(@dangerfile.status_report[:markdowns][0].message).to include(expected)
      end

      it 'prints custom failure subtitle' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.minimum_project_coverage_percentage = 30
        @my_plugin.minimum_class_coverage_percentage = 60
        @my_plugin.subtitle_failure = 'Too bad :('

        @my_plugin.report path_a

        expected = "### JaCoCo Code Coverage 32.9% :white_check_mark:\n"
        expected += "#### Too bad :(\n"
        expected += "| Class | Covered | Required | Status |\n"
        expected += "|:---|:---:|:---:|:---:|\n"
        expected += "| `com/example/CachedRepository` | 50% | 60% | :warning: |\n"
        expect(@dangerfile.status_report[:markdowns][0].message).to include(expected)
      end

      it 'prints default class column title' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| Class | Covered | Required | Status |')
      end

      it 'prints custom class column title' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

        @my_plugin.class_column_title = 'New files'

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| New files | Covered | Required | Status |')
      end

      it 'instruction coverage takes over all the rest coverages for classes' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_d.xml"

        @my_plugin.minimum_class_coverage_percentage = 50

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 71% | 50% | :white_check_mark: |')
      end

      it 'branch coverage takes over line coverage for classes, when instruction coverage is not available' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_e.xml"

        @my_plugin.minimum_class_coverage_percentage = 50

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 42% | 50% | :warning: |')
      end

      it 'line coverage takes over for classes, when both instruction coverage and branch coverage are not available' do
        path_a = "#{File.dirname(__FILE__)}/fixtures/output_f.xml"

        @my_plugin.minimum_class_coverage_percentage = 50

        @my_plugin.report path_a

        expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 93% | 50% | :white_check_mark: |')
      end

      describe 'with CachedRepository containing @Composable annotation' do
        before do
          allow(File).to receive(:exist?).with('src/java/com/example/CachedRepository.java').and_return(true)
          allow(File).to receive(:read).with('src/java/com/example/CachedRepository.java').and_return('package com.kevin.mia.mikaela class Vika { @Composable fun someUiWidget() {} }')
        end

        it 'applies minimum_composable_class_coverage_percentage' do
          path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

          @my_plugin.minimum_class_coverage_percentage = 55
          @my_plugin.minimum_composable_class_coverage_percentage = 45

          @my_plugin.report path_a

          expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 45% | :white_check_mark: |')
        end
      end

      describe 'with CachedRepository _not_ containing @Composable annotation' do
        before do
          allow(File).to receive(:exist?).with('src/java/com/example/CachedRepository.java').and_return(true)
          allow(File).to receive(:read).with('src/java/com/example/CachedRepository.java').and_return('package com.kevin.mia.mikaela class Vika { fun main() {} }')
        end

        it 'does not apply minimum_composable_class_coverage_percentage' do
          path_a = "#{File.dirname(__FILE__)}/fixtures/output_a.xml"

          @my_plugin.minimum_class_coverage_percentage = 55
          @my_plugin.minimum_composable_class_coverage_percentage = 45

          @my_plugin.report path_a

          expect(@dangerfile.status_report[:markdowns][0].message).to include('| `com/example/CachedRepository` | 50% | 55% | :warning: |')
        end
      end
    end
  end
end

# rubocop:enable Layout/LineLength
# rubocop:enable Metrics/ModuleLength
# rubocop:enable Metrics/BlockLength
