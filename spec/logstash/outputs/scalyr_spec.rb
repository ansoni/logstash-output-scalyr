# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/scalyr"
require "logstash/codecs/plain"
require "logstash/event"
require "json"



describe LogStash::Outputs::Scalyr do
  let(:sample_events) {
    events = []
    for i in 1..3 do
      e = LogStash::Event.new
      e.set('source_host', "my host #{i}")
      e.set('source_file', "my file #{i}")
      e.set('seq', i)
      e.set('nested', {'a'=>1, 'b'=>[3,4,5]})
      e.set('tags', ['t1', 't2', 't3'])
      events.push(e)
    end
    events
  }

  describe "#build_multi_event_request_array" do

    context "when a field is configured as a log attribute" do
      it "creates logfile from serverHost" do
        plugin = LogStash::Outputs::Scalyr.new({
                                                   'api_write_token' => '1234',
                                                   'serverhost_field' => 'source_host',
                                                   'log_constants' => ['tags'],
                                               })
        allow(plugin).to receive(:send_status).and_return(nil)
        plugin.register
        result = plugin.build_multi_event_request_array(sample_events)
        body = JSON.parse(result[0][:body])
        expect(body['events'].size).to eq(3)
        attrs2 = body['events'][2]['attrs']
        logattrs2 = body['logs'][2]['attrs']
        expect(logattrs2.fetch('serverHost', nil)).to eq('my host 3')
        expect(logattrs2.fetch('logfile', nil)).to eq('/logstash/my host 3')
        expect(logattrs2.fetch('tags', nil)).to eq(['t1', 't2', 't3'])
      end
    end

    context "when serverhost_field is missing" do
      it "does not contain log file" do
        plugin = LogStash::Outputs::Scalyr.new({'api_write_token' => '1234'})
        allow(plugin).to receive(:send_status).and_return(nil)
        plugin.register
        result = plugin.build_multi_event_request_array(sample_events)
        body = JSON.parse(result[0][:body])
        expect(body['events'].size).to eq(3)
        expect(body['events'][2]['attrs'].fetch('logfile', nil)).to eq(nil)
      end
    end

    context "when serverhost_field is present (or mapped)" do
      it "creates logfile from serverHost" do
        plugin = LogStash::Outputs::Scalyr.new({
                                                   'api_write_token' => '1234',
                                                   'serverhost_field' => 'source_host',
                                               })
        allow(plugin).to receive(:send_status).and_return(nil)
        plugin.register
        result = plugin.build_multi_event_request_array(sample_events)
        body = JSON.parse(result[0][:body])
        expect(body['events'].size).to eq(3)
        attrs2 = body['events'][2]['attrs']
        logattrs2 = body['logs'][2]['attrs']
        expect(logattrs2.fetch('serverHost', nil)).to eq('my host 3')
        expect(logattrs2.fetch('logfile', nil)).to eq('/logstash/my host 3')
      end
    end

    context "when serverhost_field and logfile are present (or mapped)" do
      it "does not contain log file" do
        plugin = LogStash::Outputs::Scalyr.new({
                                                   'api_write_token' => '1234',
                                                   'serverhost_field' => 'source_host',
                                                   'logfile_field' => 'source_file',
                                               })
        allow(plugin).to receive(:send_status).and_return(nil)
        plugin.register
        result = plugin.build_multi_event_request_array(sample_events)
        body = JSON.parse(result[0][:body])
        expect(body['events'].size).to eq(3)
        attrs2 = body['events'][2]['attrs']
        logattrs2 = body['logs'][2]['attrs']
        expect(logattrs2.fetch('serverHost', nil)).to eq('my host 3')
        expect(logattrs2.fetch('logfile', nil)).to eq('my file 3')
      end
    end

    context "when configured to flatten values and tags" do
      config = {
          'api_write_token' => '1234',
          'flatten_tags' => true,
          'flat_tag_value' => 'true',
          'flat_tag_prefix' => 'tag_prefix_',
          'flatten_nested_values' => true,  # this converts into string 'true'
      }
      plugin = LogStash::Outputs::Scalyr.new(config)
      it "flattens nested values and flattens tags" do
        allow(plugin).to receive(:send_status).and_return(nil)
        plugin.register
        result = plugin.build_multi_event_request_array(sample_events)
        body = JSON.parse(result[0][:body])
        expect(body['events'].size).to eq(3)
        expect(body['events'][2]['attrs']).to eq({
                                                     "nested_a" => 1,
                                                     "nested_b_0" => 3,
                                                     "nested_b_1" => 4,
                                                     "nested_b_2" => 5,
                                                     'seq' => 3,
                                                     'source_file' => 'my file 3',
                                                     'source_host' => 'my host 3',
                                                     'serverHost' => 'Logstash',
                                                     "tag_prefix_t1" => "true",
                                                     "tag_prefix_t2" => "true",
                                                     "tag_prefix_t3" => "true",
                                                 })
      end
    end

    context "when not configured to flatten values and tags" do
      config = {
          'api_write_token' => '1234',
      }
      plugin = LogStash::Outputs::Scalyr.new(config)
      it "does not flatten" do
        allow(plugin).to receive(:send_status).and_return(nil)
        plugin.register
        result = plugin.build_multi_event_request_array(sample_events)
        body = JSON.parse(result[0][:body])
        expect(body['events'].size).to eq(3)
        expect(body['events'][2]['attrs']).to eq({
                                                     "nested" => {'a'=>1, 'b'=>[3,4,5]},
                                                     'seq' => 3,
                                                     'source_file' => 'my file 3',
                                                     'source_host' => 'my host 3',
                                                     'serverHost' => 'Logstash',
                                                     "tags" => ["t1", "t2", "t3"],
                                                 })
      end
    end
  end
end
