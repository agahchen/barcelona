require 'rails_helper'

describe "API request with Vault token", type: :request do
  let(:vault_token) { 'vault-token' }
  let(:district) { create :district }
  let(:user) { create :user }

  before do
    stub_request(:get, "#{ENV['VAULT_URL']}/v1/auth/token/lookup-self").
      with(headers: {"X-Vault-Token" => vault_token}).
      to_return(body: {data: {meta: {username: user.name}}}.to_json)

    stub_request(:post, "#{ENV['VAULT_URL']}/v1/sys/capabilities-self").
      with(headers: {"X-Vault-Token" => vault_token},
           body: {path: "secret/Barcelona/#{ENV['VAULT_PATH_PREFIX']}/v1/user"}.to_json
          ).
      to_return(body: {capabilities: capabilities}.to_json)
  end

  context "when vault token has capabilities for the API" do
    let(:capabilities) { ["read"] }

    it "shows user information" do
      api_request_vault :get, "/v1/user"
      expect(response.status).to eq 200
      body = JSON.load(response.body)["user"]
      expect(body["name"]).to eq user.name
      expect(body["roles"]).to eq ["developer"]
    end
  end

  context "when vault token does not have capabilities for the API" do
    let(:capabilities) { ["deny"] }

    it "returns 403" do
      api_request_vault :get, "/v1/user"
      expect(response.status).to eq 403
    end
  end

  def api_request_vault(method, path, params={}, headers={})
    default_headers = {
      "X-Vault-Token" => vault_token,
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
    headers = default_headers.merge(headers)
    send(method, path, params: params.to_json, headers: headers)
  end
end
