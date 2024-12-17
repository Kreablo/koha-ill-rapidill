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
[% SET active = whole.rapidill_config.enabled_types.0 %]
<ul class="nav nav-tabs" role="tablist" />
   [% IF whole.rapidill_config.enabled_types.grep('^Book$').size() > 0 %]
   <li role="presentation" [% IF active == "Book" %]class="active"[% END %]><a href="#type-book" aria-controls="type-book" role="tab" data-toggle="tab">[% MSG.option_book | html %]</a></li>
   [% END %]
   [% IF whole.rapidill_config.enabled_types.grep('^Article$').size() > 0 %]
   <li role="presentation" [% IF active == "Article" %]class="active"[% END %]><a href="#type-article" aria-controls="type-article" role="tab" data-toggle="tab">[% MSG.option_article | html %]</a></li>
   [% END %]
   [% IF whole.rapidill_config.enabled_types.grep('^BookChapter$').size() > 0 %]
   <li role="presentation" [% IF active == "BookChapter" %]class="active"[% END %]><a href="#type-chapter" aria-controls="type-chapter" role="tab" data-toggle="tab">[% MSG.option_book_chapter | html %]</a></li>
   [% END %]
</ul>
<div class="tab-content">
 [% IF whole.rapidill_config.enabled_types.grep('^Book$') %]
  <div role="tabpanel" class="tab-pane active" id="type-book">
    [% PROCESS render_create_form rapid_request_type="Book" %]
  </div>
 [% END %]
 [% IF whole.rapidill_config.enabled_types.grep('^Article$') %]
  <div role="tabpanel" class="tab-pane" id="type-article">
    [% PROCESS render_create_form rapid_request_type="Article" %]
  </div>
 [% END %]
 [% IF whole.rapidill_config.enabled_types.grep('^BookChapter$') %]
  <div role="tabpanel" class="tab-pane" id="type-chapter">
    [% PROCESS render_create_form rapid_request_type="BookChapter" %]
  </div>
 [% END %]
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
