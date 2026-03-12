module FileUploadRestrictions
  module FilesControllerOverrides
    extend ActiveSupport::Concern

      def api_create
        @policy, @attachment = Attachment.decode_policy(params[:Policy], params[:Signature])
        @context = @attachment.context
        size_limit = @context&.account && @context&.account.max_file_size[:value]&.to_f

        if (file_size_plugin = Canvas::Plugin.find("file_upload_restrictions")) && file_size_plugin.enabled? && (file_size_plugin.settings[:enable_file_types] == "true")
          uploaded_data = params[:attachment]&.[](:uploaded_data)
          if uploaded_data && !(Account::Settings.file_type_restrictions.include? File.extname(uploaded_data.original_filename).delete_prefix("."))
            custom_message = Canvas::Plugin.find("file_upload_restrictions").settings[:file_type_error_message]
            not_allowed = custom_message.nil? ? "File type not allowed." : custom_message
            render status: :unsupported_media_type, json: {
              aj_message: not_allowed,
              message: not_allowed
            }
            return
          end
          if (uploaded_data&.tempfile && size_limit && ((size_limit * 1024 * 1024) <= uploaded_data.tempfile.size))
            render status: :payload_too_large, json: {
              message: "File size is larger than allowed maximum of #{size_limit} MB",
              aj_message: "File size is larger than allowed maximum of #{size_limit} MB"
            }
            return
          end
        end
        super
      end
  end
end
