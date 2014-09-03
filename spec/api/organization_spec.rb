# -*- coding: utf-8 -*-
#
# Author:: Ho-Sheng Hsiao (<hosh@opscode.com>)
# Author:: Tyler Cloke (<tyler@getchef.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.

require 'pedant/rspec/common'
require 'json'

describe "/organizations", :organizations do

  def self.ruby?
    Pedant::Config.ruby_organizations_endpoint?
  end

  describe "GET /organizations" do
    let(:request_url)    { "#{platform.server}/organizations" }
    let(:requestor)      { superuser }

    context "when the user requests a list of organizations" do
      it "should return a valid list of organizations" do
        get(request_url, requestor).should look_like(
          # Would actually probably contain additional orgs in body, but this is the only
          # one we know is there.
          :body => {
            platform.test_org.name => "#{platform.server}/organizations/#{platform.test_org.name}"
          },
          :status => 200
        )
      end
    end

  end

  describe "GET /organizations/:id" do
    let(:request_url)    { "#{platform.server}/organizations/#{platform.test_org.name}" }
    let(:requestor)      { superuser }

    context "when the user requests a valid organization" do

      it "should return a valid organization object" do
        get(request_url, requestor).should look_like(
          # Would actually probably contain additional orgs in body, but this is the only
          # one we know is there.
          :body => {
            "name"                     => platform.test_org.name,
            "full_name"                => platform.test_org.name,
            # -- TODO - remove these
            # I'm only commenting them out in case the webui depends on one of these
            # and we determine that we need to come back and re-implement them at some
            # point
            # "org_type"                 => "Business",
            # "clientname"               => "#{platform.test_org.name}-validator",
            # "chargify_subscription_id" => nil,
            # "chargify_customer_id"     => nil,
            # "billing_plan"             => "platform-free",
          },
          :status => 200
        )

      end

      pending("erlang will not return the guid", :if => !ruby?) do
        it "should return a organization object that contains a valid guid" do
          parsed_response = JSON.parse(get(request_url, requestor))
          parsed_response["guid"].should have(32).characters
        end
      end

      pending("erlang will not return the assigned_at field", :if => !ruby?) do
        it "should return a valid assigned_at field of the format YYYY/MM/DD HH:MM:SS [+-]TTTT" do
          parsed_response = JSON.parse(get(request_url, requestor))
          parts = parsed_response["assigned_at"].split

          /^\d{4}[-\/]\d{1,2}[-\/]\d{1,2}$/.should match(parts[0])
          /^(\d{2}):(\d{2}):(\d{2})$/.should match(parts[1])
          /^[+-]\d\d\d\d$/.should match(parts[2])
        end
      end
    end

  end

  describe "POST /organizations"  do
    let(:orgname) { "test-#{Time.now.to_i}-#{Process.pid}" }
    let(:request_body) do
      {
        full_name: "fullname-#{orgname}",
        name: orgname,
        org_type: "Business",
      }
    end

    context "when the user posts a new organization with a valid body and name" do

      after :each do
        delete("#{platform.server}/organizations/#{orgname}", superuser)
      end

      it "should respond with a valid newly created organization" do
        post("#{platform.server}/organizations", superuser, :payload => request_body).should look_like(
          :body => {
            "clientname" => "#{orgname}-validator",
            "uri" => "#{platform.server}/organizations/#{orgname}"
          },
          :status => 201
        )
      end

# Note:
# Currently excluded because it fails intermittently.
# To re-enable, please remove ', :intermittent_failure => true'
      it "should respond with data containing a valid private key",  :intermittent_failure => true do
        result = JSON.parse(post("#{platform.server}/organizations", superuser, :payload => request_body))
        /-----BEGIN RSA PRIVATE KEY-----/.should match(result["private_key"])
      end
    end

  end

  describe "PUT /organizations/:id" do
    let(:orgname) { "test-#{Time.now.to_i}-#{Process.pid}" }
    let(:post_request_body) do
      {
        full_name: "fullname-#{orgname}",
        name: orgname,
        org_type: "Business"
      }
    end

    before :each do
      post("#{platform.server}/organizations", superuser, :payload => post_request_body)
    end

    after :each do
      delete("#{platform.server}/organizations/#{orgname}", superuser)
    end

    context "when the user renames the organization object with modifications", :rename_org do
      let(:new_orgname) { "test-#{Time.now.to_i*3}-#{Process.pid}" }
      let(:payload) do
        {
          'name' => new_orgname,
          'org_type' => "Pleasure",
          'full_name' => new_orgname
        }
      end

      # our standard response for erlang requests is to return the json that was posted
      let(:update_response_body) do
        if ruby?
          {"uri" => "#{platform.server}/organizations/#{new_orgname}"}
        else
          payload
        end
      end

      # since we no longer track or return 'org_type', ignore it in erlang mode
      let(:get_response_body) do
        resp = payload.dup
        resp.delete('org_type') unless ruby?
        resp
      end

      after :each do
        delete("#{platform.server}/organizations/#{new_orgname}", superuser)
      end

      it "should update the organization object" do
        # TODO: we don't validate org_type at all
        put("#{platform.server}/organizations/#{orgname}", superuser, :payload => payload).should look_like(
          :status => ruby? ? 200 : 201,
          :body => update_response_body
        )

        get("#{platform.server}/organizations/#{new_orgname}", superuser).should look_like(
          :status => 200,
          :body => get_response_body
        )
      end
    end

    context "when the user updates fields in the organization with valid data" do
      let(:payload) do
        payload = {
          'name' => orgname,
          'org_type' => "Pleasure",
          'full_name' => orgname
        }
      end

      # our standard response for erlang requests is to return the json that was posted
      let(:update_response_body) do
        if ruby?
          {"uri" => "#{platform.server}/organizations/#{new_orgname}"}
        else
          payload
        end
      end

      # since we no longer track or return 'org_type', ignore it in erlang mode
      let(:get_response_body) do
        resp = payload.dup
        resp.delete('org_type') unless ruby?
        resp
      end

      it "should update the organization object" do
        # TODO: we don't validate org_type at all
        put("#{platform.server}/organizations/#{orgname}", superuser, :payload => payload).should look_like(
          :status => 200,
          :body => update_response_body
        )

        get("#{platform.server}/organizations/#{orgname}", superuser).should look_like(
          :status => 200,
          :body => get_response_body
        )
      end
    end

    context "when the user tries to post a private_key", :validation do
      it "throws an error related to no longer supporting PUT for key updating" do
        request = put("#{platform.server}/organizations/#{orgname}", superuser,
                      :payload => {private_key: "some_unused_key"})

        request.should look_like(
         :status => 410
        )

        JSON.parse(request).should have_key("error")
      end
    end

  end

  ##########################
  # Internal account tests #
  ##########################

  # describe "POST /internal-organizations", :internal_orgs do
  #   let(:orgname)      { "precreated-#{Time.now.to_i}-#{Process.pid}" }
  #   let(:request_body) do
  #     {
  #       full_name: "Pre-created",
  #       name: orgname,
  #       org_type: "Business",
  #     }
  #   end

  #   after :each do
  #     delete("#{platform.server}/organizations/#{orgname}", superuser)
  #   end

  #   context "when creating a new org" do
  #     it "should respond with a valid newly created organization" do
  #       request = authenticated_request(:POST, "#{platform.internal_account_url}/internal-organizations",
  #         superuser, :payload => request_body)

  #       request.should look_like(
  #           :body => {
  #             "clientname" => "#{orgname}-validator",
  #           },
  #           :status => 201
  #       )
  #       JSON.parse(request).should have_key("uri")
  #     end
  #   end

  #   context "when attempting to create a new org and that org already exists" do
  #     it "should respond with a conflict" do
  #       # seed the org
  #       authenticated_request(:POST, "#{platform.internal_account_url}/internal-organizations", superuser, :payload => request_body)

  #       authenticated_request(:POST, "#{platform.internal_account_url}/internal-organizations", superuser,
  #         :payload => request_body).should look_like(
  #           :status => 409,
  #           :body => {
  #             "error" => "Organization already exists."
  #           }
  #       )
  #     end
  #   end

  # end

  # describe "PUT /internal-organizations", :internal_orgs do

  #   let(:orgname) { "precreated-#{Time.now.to_i}-#{Process.pid}" }
  #   let(:post_request_body) do
  #     {
  #       full_name: "Pre-created",
  #       name: orgname,
  #       org_type: "Business",
  #     }
  #   end

  #   before :each do
  #     authenticated_request(:POST, "#{platform.internal_account_url}/internal-organizations", superuser, :payload => post_request_body)
  #   end

  #   after :each do
  #     delete("#{platform.server}/organizations/#{orgname}", superuser)
  #   end

  #   context "when an org is updated to unassigned = true with a PUT" do
  #     let(:put_request_body) do
  #       {
  #         unassigned: true,
  #       }
  #     end

  #     it "should update the organization's unassigned field" do
  #       # since there is no way of actually getting the assigned field back from the API that I know of
  #       # best tests I can think of
  #       request = authenticated_request(:PUT,"#{platform.internal_account_url}/internal-organizations/#{orgname}",          superuser, :payload => put_request_body)
  #       request.should look_like(:status => 200)
  #       JSON.parse(request).should have_key("uri")

  #       get("#{platform.server}/organizations/ponyville", superuser).should look_like(
  #         :body => {
  #           "assigned_at "=> nil
  #         }
  #       )
  #     end
  #   end

  #   # TODO: PUT only accepts unassigned: true, which I think is interesting behavior
  #   # for an API. If the only thing it does is set assigned to true, why not not have a
  #   # payload at all and maybe make the API more explicit like
  #   # PUT /internal-organizations/unassign/:id/
  #   context "when an org is updated to unassigned = false with a PUT" do
  #     let(:put_request_body) do
  #       {
  #         unassigned: false,
  #       }
  #     end

  #     it "should return a bad request error" do
  #       authenticated_request(:PUT, "#{platform.internal_account_url}/internal-organizations/#{orgname}",
  #         superuser, :payload => put_request_body).should look_like(
  #           :body => {
  #             "error" => "Cannot assign org #{orgname} - unassigned=true is only allowable operation",
  #           },
  #           :status => 400
  #       )
  #     end
  #   end
  # end

end
