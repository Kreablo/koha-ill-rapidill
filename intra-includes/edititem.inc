[% cwd = whole.cwd %]
[% TRY %]
    [% lang_file = "${cwd}/l10n/${whole.lang_dialect}"_".inc" %]
    [% PROCESS "$lang_file" %]
[% CATCH %]
    [% TRY %]
        [% lang_file = "${cwd}/l10n/${whole.lang_all}"_".inc" %]
        [% PROCESS "$lang_file" %]
    [% CATCH %]
        [% PROCESS "${cwd}/l10n/default.inc" %]
    [% END %]
[% END %]
[% SET illrequest_id = request.illrequest_id %]
[% SET requests_back_url = "/cgi-bin/koha/ill/ill-requests.pl?op=illview&illrequest_id=$illrequest_id" %]
[% SET action_url = '/cgi-bin/koha/ill/ill-requests.pl' %]
[% SET cud_op = 'cud-edititem' %]

<h2>[% MSG.edit_request %]</h2>
[% PROCESS "${cwd}/shared-includes/form.inc" %]
[% SET staff = 1 %]
[% PROCESS render_edit_form rapid_request_type=whole.value.other.RapidRequestType %]
<style>
  ul.fields li {
    list-style-type: none;
  }
</style>
<script>
    document.addEventListener('DOMContentLoaded', function(){
        var fieldmap = [% whole.field_map_json %];
        [% INCLUDE "${cwd}/shared-includes/create.js" %]
        [% INCLUDE "${cwd}/shared-includes/crossref.js" %]
    });
    //]]>
</script>