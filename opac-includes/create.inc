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
[% SET active = whole.rapidill_config.enabled_types.0 %]
<ul class="nav nav-tabs" role="tablist" />
   [% IF whole.rapidill_config.enabled_types.grep('^Book$').size() > 0 %]
   <li role="presentation" class="nav-item"><a class="nav-link[% IF active == "Book" %] active[% END %]" href="#type-book" aria-controls="type-book" role="tab" data-toggle="tab">[% MSG.option_book %]</a></li>
   [% END %]
   [% IF whole.rapidill_config.enabled_types.grep('^Article$').size() > 0 %]
   <li role="presentation" class="nav-item"><a class="nav-link[% IF active == "Article" %] active[% END %]" href="#type-article" aria-controls="type-article" role="tab" data-toggle="tab">[% MSG.option_article %]</a></li>
   [% END %]
   [% IF whole.rapidill_config.enabled_types.grep('^BookChapter$').size() > 0 %]
   <li role="presentation" class="nav-item"><a class="nav-link[% IF active == "BookChapter" %] active[% END %]" href="#type-chapter" aria-controls="type-chapter" role="tab" data-toggle="tab">[% MSG.option_book_chapter %]</a></li>
   [% END %]
</ul>
<div class="tab-content">
   [% IF whole.rapidill_config.enabled_types.grep('^Book$').size() > 0 %]
  <div role="tabpanel" class="tab-pane[% IF active == "Book" %] active[% END %]" id="type-book">
    [% PROCESS render_create_form rapid_request_type="Book" %]
  </div>
   [% END %]
   [% IF whole.rapidill_config.enabled_types.grep('^Article$').size() > 0 %]
  <div role="tabpanel" class="tab-pane[% IF active == "Article" %] active[% END %]" id="type-article">
    [% PROCESS render_create_form rapid_request_type="Article" %]
  </div>
   [% END %]
   [% IF whole.rapidill_config.enabled_types.grep('^BookChapter$').size() > 0 %]
  <div role="tabpanel" class="tab-pane[% IF active == "BookChapter" %] active[% END %]" id="type-chapter">
    [% PROCESS render_create_form rapid_request_type="BookChapter" %]
  </div>
   [% END %]
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
