[% USE Koha %]
[% USE Asset %]
[% USE raw %]
[% SET koha_version = Koha.Version %]
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

[% SET cwd = whole.cwd %]
[% PROCESS "${cwd}/shared-includes/form.inc" %]
[% SET staff = 1 %]
[% SET requests_back_url = '/cgi-bin/koha/ill/ill-requests.pl' %]

[% PROCESS render_errors %]

[% IF whole.stage == "commit" %]
<p>[% MSG.created_request_confirm | html %]</p>

[% ELSIF whole.stage == "init" %]
<ul class="nav nav-tabs" role="tablist" />
   <li role="presentation" class="active"><a href="#type-book" aria-controls="type-book" role="tab" data-toggle="tab">[% MSG.option_book | html %]</a></li>
   <li role="presentation"><a href="#type-article" aria-controls="type-article" role="tab" data-toggle="tab">[% MSG.option_article | html %]</a></li>
   <li role="presentation"><a href="#type-chapter" aria-controls="type-chapter" role="tab" data-toggle="tab">[% MSG.option_book_chapter | html %]</a></li>
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
[% END %]
<style>
  ul.fields li {
    list-style-type: none;
  }
</style>
[% BLOCK backend_jsinclude %]
<script>
  // Require a username and branch selection
  document.addEventListener('DOMContentLoaded', function(){


      var fieldmap = [% whole.field_map_json %];

      [% INCLUDE "${cwd}/shared-includes/create.js" %]

  });
  //]]>
</script>
[% END %]
