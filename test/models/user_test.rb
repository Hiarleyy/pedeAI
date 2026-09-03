require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "superAdmin pertence a um restaurante e tem todas as permissões dele" do
    restaurant = Restaurant.create!(name: "Restaurante Teste")
    user = User.new(name: "Dono", email: "dono@example.com", password: "secret123", role: "superAdmin", restaurant: restaurant)

    assert user.valid?
    assert user.allowed?("qualquer:acao")
  end

  test "todo usuário precisa pertencer a um restaurante" do
    %w[superAdmin admin funcionario].each do |role|
      user = User.new(name: "Usuário", email: "#{role}@example.com", password: "secret123", role: role)

      assert_not user.valid?
      assert_includes user.errors[:restaurant], "must exist"
    end
  end

  test "restaurante só pode ter um superAdmin" do
    restaurant = Restaurant.create!(name: "Restaurante Teste")
    User.create!(name: "Dono", email: "dono@example.com", password: "secret123", role: "superAdmin", restaurant: restaurant)
    another_owner = User.new(name: "Outro Dono", email: "outro@example.com", password: "secret123", role: "superAdmin", restaurant: restaurant)

    assert_not another_owner.valid?
    assert_includes another_owner.errors[:role], "já possui um superAdmin"
  end

  test "superAdmin não pode ser removido nem rebaixado" do
    restaurant = Restaurant.create!(name: "Restaurante Teste")
    owner = User.create!(name: "Dono", email: "dono@example.com", password: "secret123", role: "superAdmin", restaurant: restaurant)

    assert_not owner.update(role: "admin")
    assert_equal "superAdmin", owner.reload.role
    assert_not owner.destroy
    assert User.exists?(owner.id)
  end

  test "funcionário só possui as permissões concedidas" do
    restaurant = Restaurant.create!(name: "Restaurante Teste")
    user = User.create!(name: "Equipe", email: "equipe@example.com", password: "secret123", role: "funcionario", restaurant: restaurant, permissions: { "orders:read" => true })

    assert user.allowed?("orders:read")
    assert_not user.allowed?("products:write")
  end
end
