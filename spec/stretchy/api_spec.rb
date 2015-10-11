require 'spec_helper'

module Stretchy
  describe API do

    let(:api) { API.new(index: SPEC_INDEX, type: FIXTURE_TYPE) }
    subject   { api }

    describe 'pagination' do

      describe '#limit' do
        subject { api.limit(10) }

        it 'propagates to request' do
          expect(subject.request[:size]).to eq(10)
        end

        it 'fetches' do
          expect(subject.limit).to eq(10)
        end
      end

      describe '#offset' do
        subject { api.offset(10) }

        it 'propagates to request' do
          expect(subject.request[:from]).to eq(10)
        end

        it 'fetches' do
          expect(subject.offset).to eq(10)
        end

        it 'aliases as limit_value' do
          expect(subject.limit_value).to eq(10)
        end
      end

      describe '#page' do
        it 'fetches 0-19 for page 1' do
          request = subject.page(1, per_page: 20).request
          expect(request[:from]).to eq(0)
          expect(request[:size]).to eq(20)
        end

        it 'fetches 20-49 for page 2' do
          request = subject.page(2, per_page: 20).request
          expect(request[:from]).to eq(20)
          expect(request[:size]).to eq(20)
        end

        it 'fetches' do
          page = subject.page(2, per_page: 20).page
          expect(page).to eq(2)
        end
      end

      describe '#current_page' do
        it 'fetches' do
          page = subject.page(2, per_page: 20).current_page
          expect(page).to eq(2)
        end
      end

    end

    describe '#filter_node' do
      subject { api.match(name: 'sakurai') }

      it 'does build response before checking with collector' do
        expect_any_instance_of(API).not_to receive(:results_obj)
        subject.filter_node.json
      end
    end

    describe '#opts' do
      subject { described_class.new(one: 1, two: 2).match(name: 'sakurai')}

      it 'preserves unknown input options' do
        expect(subject.opts).to include(one: 1, two: 2)
      end
    end
  end
end