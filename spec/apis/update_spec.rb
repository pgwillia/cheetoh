require "rails_helper"

describe "update", :type => :api, vcr: true, :order => :defined do
  let(:doi) { "10.5072/0000-03vc" }
  let(:username) { ENV['MDS_USERNAME'] }
  let(:password) { ENV['MDS_PASSWORD'] }
  let(:headers) do
    { "HTTP_ACCEPT" => "text/plain",
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) }
  end
  context "missing" do
    it "missing valid doi parameter" do
      doi = "20.5072/0000-03vc"
      post "/id/doi:#{doi}", nil, headers
      expect(last_response.status).to eq(400)
      expect(last_response.body).to eq("error: bad request - no such identifier")
    end

    it "missing login credentials" do
      post "/id/doi:#{doi}"
      expect(last_response.status).to eq(401)
      expect(last_response.headers["WWW-Authenticate"]).to eq("Basic realm=\"ez.test.datacite.org\"")
      expect(last_response.body).to eq("HTTP Basic: Access denied.\n")
    end
  end
end
