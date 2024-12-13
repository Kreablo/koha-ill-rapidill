[% cwd = whole.cwd %]
[% SET illrequest_id = request.illrequest_id %]
[% SET requests_back_url = "/cgi-bin/koha/ill/ill-requests.pl?op=illview&illrequest_id=$illrequest_id" %]

<h2>Edit request</h2>
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
    });
    //]]>
</script>