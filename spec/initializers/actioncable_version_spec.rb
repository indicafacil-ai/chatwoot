require 'rails_helper'

# rubocop:disable RSpec/DescribeClass -- the subject is the Listener patch in config/initializers/actioncable.rb.
describe 'Action Cable Redis listener patch' do
  it 'runs on the actioncable minor its overrides were written against' do
    # Measured on 25/11/2026: lib/action_cable/subscription_adapter/redis.rb of actioncable 8.1.4.1 is the
    # 8.0.5.2 file but for the redis gem bound (< 7), so the overrides below still match line for line.
    expect(ActionCable.gem_version.segments.first(2)).to eq([8, 1]), <<~MESSAGE.squish
      actioncable is #{ActionCable.gem_version}, but ActionCableRedisListenerRecovery in
      config/initializers/actioncable.rb overrides private methods of the actioncable 8.1 Redis
      Listener (unchanged from 8.0 and 7.2). Read the Listener of this version and the state of rails/rails#58939 and
      rails/rails#59043, adjust or drop the patch, then update this pin.
    MESSAGE
  end
end
# rubocop:enable RSpec/DescribeClass
