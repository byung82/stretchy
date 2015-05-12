require 'spec_helper'

describe Stretchy::Clauses::BoostClause do
  let(:base) { Stretchy::Clauses::Base.new }
  subject    { described_class.new(base) }

  describe 'initialize with' do
    specify 'base' do
      instance = described_class.new(base)
      expect(instance).to be_a(described_class)
    end

    specify 'inverse option' do
      instance = described_class.new(base, inverse: true)
      expect(instance.inverse?).to eq(true)
    end
  end

  describe 'can add option' do

    specify 'random' do
      expect(subject.random(27).boost_builder.functions).to include(Stretchy::Boosts::RandomBoost)
    end

    specify 'global' do
      expect(subject.all(33).boost_builder.overall_boost).to eq(33)
    end

    specify 'max' do
      expect(subject.max(84).boost_builder.max_boost).to eq(84)
    end

    specify 'score mode' do
      expect(subject.score_mode('avg').boost_builder.score_mode).to eq('avg')
    end

    specify 'boost mode' do
      expect(subject.boost_mode('avg').boost_builder.boost_mode).to eq('avg')
    end

    specify 'not' do
      expect(subject.not.inverse?).to eq(true)
    end

    specify 'where' do
      expect(subject.where).to be_a(Stretchy::Clauses::BoostWhereClause)
    end

    specify 'match' do
      expect(subject.match).to be_a(Stretchy::Clauses::BoostMatchClause)
    end

    describe 'near' do

      specify 'geo point' do
        clause = subject.near(field: :coords, lat: 23.3, lng: 28.8, scale: '10km')
        fn = clause.boost_builder.functions.first
        expect(fn).to be_a(Stretchy::Boosts::FieldDecayBoost)
        expect(fn.field).to eq(:coords)
        expect(fn.origin).to be_a(Stretchy::Types::GeoPoint)
        expect(fn.origin.lat).to eq(23.3)
        expect(fn.origin.lon).to eq(28.8)
        expect(fn.scale).to eq('10km')
      end

      it 'is aliased as geo' do
        clause = subject.geo(field: :coords, lat: 23.3, lng: 28.8, scale: '10km')
        fn = clause.boost_builder.functions.first
        expect(fn).to be_a(Stretchy::Boosts::FieldDecayBoost)
        expect(fn.origin).to be_a(Stretchy::Types::GeoPoint)
      end

      specify 'date' do
        time = Time.now
        clause = subject.near(field: :published, origin: time, scale: '3d')
        fn = clause.boost_builder.functions.first
        
        expect(fn).to be_a(Stretchy::Boosts::FieldDecayBoost)
        expect(fn.field).to eq(:published)
        expect(fn.origin).to eq(time)
        expect(fn.scale).to eq('3d')
      end

      specify 'number' do
        clause = subject.near(field: :rank, origin: 27, scale: 2)
        fn = clause.boost_builder.functions.first
        
        expect(fn).to be_a(Stretchy::Boosts::FieldDecayBoost)
        expect(fn.field).to eq(:rank)
        expect(fn.origin).to eq(27)
        expect(fn.scale).to eq(2)
      end
    end
  end

  describe 'does not chain from' do

    def check_instance(instance)
      expect(instance).to be_a(Stretchy::Clauses::WhereClause)
      expect(instance.where_builder.terms[:my_field]).to include(3)
    end

    specify 'near' do
      instance = subject.near(field: :published, origin: Time.now, scale: '3d').where(my_field: 3)
      expect(instance.boost_builder.functions).to include(Stretchy::Boosts::FieldDecayBoost)
      check_instance(instance)
    end

    specify 'random' do
      instance = subject.random(100).where(my_field: 3)
      expect(instance.boost_builder.functions).to include(Stretchy::Boosts::RandomBoost)
      check_instance(instance)
    end
  end
end