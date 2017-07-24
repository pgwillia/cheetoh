require "rails_helper"

describe "/id/show", :type => :api, vcr: true do
  it "show doi and metadata" do
    doi = "10.4124/XZ7JTC6TBB.1"

    get "/id/doi:#{doi}"
    expect(last_response.status).to eq(200)
    response = last_response.body
    hsh = response.from_anvl
    expect(hsh["success"]).to eq("doi:10.4124/xz7jtc6tbb.1")
    expect(hsh["_updated"]).to eq("1500649550")
    expect(hsh["_target"]).to eq("https://staging-data.mendeley.com/datasets/xz7jtc6tbb/1")
    expect(hsh["datacite"]).to start_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<resource xmlns=\"http://datacite.org/schema/kernel-3\"")
    expect(hsh["_profile"]).to eq("datacite")
    expect(hsh["_datacenter"]).to eq("BL.MENDELEY")
    expect(hsh["_export"]).to eq("yes")
    expect(hsh["_created"]).to eq("1500649550")
    expect(hsh["_status"]).to eq("public")
  end

  it "missing valid doi parameter" do
    doi = "20.5072/0000-03vc"
    put "/id/doi:#{doi}"
    expect(last_response.status).to eq(404)
    expect(last_response.body).to eq("error: the resource you are looking for doesn't exist.")
  end

  it "not found" do
    get "/id/x"
    expect(last_response.status).to eq(404)
    expect(last_response.body).to eq("error: the resource you are looking for doesn't exist.")
  end
end
