[% USE Koha %]

[% cwd = whole.cwd %]
[% PROCESS "${cwd}/shared-includes/form.inc" %]
[% SET staff = 0 %]
[% SET requests_back_url = '/cgi-bin/koha/opac-illrequests.pl' %]
[% TRY %]
    [% lang_file = "${whole.cwd}/l10n/${whole.lang_dialect}"_".inc" %]
    [% PROCESS "$lang_file" %]
[% CATCH %]
    [% TRY %]
        [% lang_file = "${whole.cwd}/l10n/${whole.lang_all}"_".inc" %]
        [% PROCESS "$lang_file" %]
    [% CATCH %]
        [% PROCESS "${whole.cwd}/l10n/default.inc" %]
    [% END %]
[% END %]

[% IF whole.error %]
  [% IF whole.status == 'missing_fields' %]
    <p><em>Please Note:</em> Some mandatory fields are missing.</p>
  [% ELSIF whole.status == 'missing_branch' %]
    <p><em>Please Note:</em> Branch is a mandatory field.</p>
  [% ELSIF whole.status == 'invalid_borrower' %]
    <p><em>Please Note:</em> The borrower details you entered are invalid.</p>
  [% ELSIF whole.status == 'invalid_branch' %]
    <p><em>Please Note:</em> The branch you chose is invalid.</p>
  [% ELSIF whole.status == 'invalid_metadata' %]
    <p><em>Please Note:</em> You did not supply the correct metadata for the selected material type.</p>
  [% ELSIF whole.status == 'api' %]
    <p><em>Please Note:</em> there was an error whilst communicating with the remote service.</p>
  [% ELSIF whole.message %]
    <p><em>[% whole.message %]</em></p>
  [% ELSE %]
    <p><em>Unhandled error</em></p>
  [% END %]
[% END %]

[% IF whole.stage == "commit" %]
<p>We have now created your request.</p>

[% ELSIF whole.stage == "init" %]
<ul class="nav nav-tabs" role="tablist" />
   <li role="presentation" class="active nav-item"><a class="nav-link active" href="#type-book" aria-controls="type-book" role="tab" data-toggle="tab">[% MSG.option_book %]</a></li>
   <li role="presentation" class="nav-item"><a class="nav-link" href="#type-article" aria-controls="type-article" role="tab" data-toggle="tab">[% MSG.option_article %]</a></li>
   <li role="presentation" class="nav-item"><a class="nav-link" href="#type-chapter" aria-controls="type-chapter" role="tab" data-toggle="tab">[% MSG.option_book_chapter %]</a></li>
</ul>
<div class="tab-content">
  <div role="tabpanel" class="tab-pane active" id="type-book">
    [% PROCESS render_create_form rapid_request_type="Book" %]
  </div>
  <div role="tabpanel" class="tab-pane" id="type-article">
    [% PROCESS render_create_form rapid_request_type="Article" %]
  </div>
  <div role="tabpanel" class="tab-pane" id="type-chapter">
    [% PROCESS render_create_form rapid_request_type="BookChapter" %]
  </div>
</div>
<style>
  ul.fields li {
    list-style-type: none;
  }
</style>
[% BLOCK backend_jsinclude %]
<script>
  document.addEventListener('DOMContentLoaded', function(){
    var fieldmap = [% whole.field_map_json %];
    [% INCLUDE "${cwd}/shared-includes/create.js" %]
  });
</script>
[% END %]

[% END %]
