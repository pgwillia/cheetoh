class WorksController < ApplicationController
  prepend_before_action :authenticate_user_with_basic_auth!, except: [:show]
  before_action :set_profile
  before_action :set_work, except: [:mint, :create]

  before_bugsnag_notify :add_metadata_to_bugsnag

  def show
    fail AbstractController::ActionNotFound unless @work.present?

    render plain: @work.hsh.to_anvl
  end

  def mint
    # Rails.logger.info safe_params.inspect
    fail IdentifierError, "no _profile provided" unless
      profile_present?(safe_params)
    fail IdentifierError, "no _target provided" if
      (safe_params[:_target].blank? && safe_params[:_status] != "reserved")

    # make sure we generate a random DOI that is not already used
    # allow seed with number for deterministic minting (e.g. testing)
    if safe_params[:_number].present?
      doi = generate_random_doi(params[:id], number: safe_params[:_number])

      work = Work.where(doi: doi)
      fail IdentifierError, "doi:#{doi} has already been registered" if work.present?
    else
      duplicate = true
      while duplicate do
        doi = generate_random_doi(params[:id])
        work = Work.where(doi: doi)
        duplicate = work.present?
      end
    end

    input = safe_params[@profile].present? ? safe_params[@profile].anvlunesc : nil

    options = {
      input: input,
      from: @profile.to_s,
      doi: doi,
      target: safe_params[:_target],
      target_status: safe_params[:_status]
    }

    options = options.merge(
      author: safe_params["datacite.creator"],
      title: safe_params["datacite.title"],
      publisher: safe_params["datacite.publisher"],
      published: safe_params["datacite.publicationyear"],
      resource_type_general: safe_params["datacite.resourcetype"]) if @profile.to_s == "datacite"

    @work = Work.new(options)

    message, status = @work.create_record(username: @username,
                                          password: @password)
    render plain: message, status: status
  end

  def create
    doi = validate_doi(params[:id])
    fail IdentifierError, "ark identifiers are not supported by this service" if is_ark?(params[:id])
    fail IdentifierError, "no doi provided" unless doi.present?
    fail IdentifierError, "no _profile provided" unless
      profile_present?(safe_params)
    fail IdentifierError, "no _target provided" if
      (safe_params[:_target].blank? && safe_params[:_status] != "reserved")
    
    work = Work.where(doi: doi)
    fail IdentifierError, "doi:#{doi} has already been registered" if work.present?

    input = safe_params[@profile].present? ? safe_params[@profile].anvlunesc : nil

    options = {
      input: input,
      from: @profile.to_s,
      doi: doi,
      target: safe_params[:_target],
      target_status: safe_params[:_status]
    }

    options = options.merge(
      author: safe_params["datacite.creator"],
      title: safe_params["datacite.title"],
      publisher: safe_params["datacite.publisher"],
      published: safe_params["datacite.publicationyear"],
      resource_type_general: safe_params["datacite.resourcetype"]) if @profile.to_s == "datacite"

    @work = Work.new(options)

    message, status = @work.create_record(username: @username,
                                          password: @password)
    render plain: message, status: status
  end

  def update
    fail IdentifierError, "No _profile, _target or _status provided" unless
      safe_params[@profile].present? ||
      safe_params[:_target].present? ||
      safe_params[:_status].present?

    if safe_params[@profile].present?
      @work.input = safe_params[@profile].anvlunesc 
      @work.from = @profile.to_s

      if @profile.to_s == "datacite"
        @work.author = safe_params["datacite.creator"]
        @work.title = safe_params["datacite.title"]
        @work.publisher = safe_params["datacite.publisher"]
        @work.published = safe_params["datacite.publicationyear"]
        @work.resource_type_general = safe_params["datacite.resourcetype"]
      end 
    end

    @work.target = safe_params[:_target] if safe_params[:_target].present?
    @work.target_status = safe_params[:_status] if safe_params[:_status].present?

    message, status = @work.update_record(username: @username,
                                          password: @password)
    render plain: message, status: status
  end

  def delete
    fail IdentifierError, "#{params[:id]} is not a reserved DOI" unless @work.reserved?

    message, status = @work.delete_record(username: @username,
                                          password: @password)
    render plain: message, status: status
  end

  protected

  def profile_present?(safe_params)
    safe_params[:_status] == "reserved" ||
    safe_params[@profile].present? ||
    safe_params["datacite.creator"].present? &&
    safe_params["datacite.title"].present? &&
    safe_params["datacite.publisher"].present? &&
    safe_params["datacite.publicationyear"].present? &&
    safe_params["datacite.resourcetype"].present? 
  end

  def set_profile
    @profile = safe_params[:_profile].presence || :datacite
    fail IdentifierError, "#{safe_params[:_profile]} profile not supported by this service" unless
      SUPPORTED_PROFILES[@profile.to_sym].present?
  end

  def set_work
    doi = validate_doi(params[:id])
    fail IdentifierError, "ark identifiers are not supported by this service" if is_ark?(params[:id])
    fail AbstractController::ActionNotFound unless doi.present?

    @work = Work.where(doi: doi, profile: @profile)
    fail AbstractController::ActionNotFound unless @work.present?
  end

  private

  def safe_params
    params.permit(:id, :_target, :_export, :_profile, :_status, :_number, :datacite, :bibtex, :ris, :schema_org, :citeproc).merge(request.raw_post.from_anvl)
  end

  def add_metadata_to_bugsnag(report)
    return nil unless safe_params[@profile].present?

    report.add_tab(:metadata, {
      metadata: safe_params[@profile]
    })
  end
end
