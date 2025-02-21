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
[% SET action_url = '/cgi-bin/koha/ill/ill-requests.pl' %]
[% SET cud_op = 'cud-create' %]

[% PROCESS render_errors %]

<p>[% whole.value.FOO | html %]

[% IF whole.stage == "commit" %]
<p>[% MSG.created_request_confirm | html %]</p>

[% ELSIF whole.stage == "init" %]
[% SET active = whole.value.other.RapidRequestType ? whole.value.other.RapidRequestType : whole.rapidill_config.enabled_types.0 %]
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
[% END %]
<style>
  ul.fields li {
    list-style-type: none;
  }
  .soft-required label::after, .hard-required label::after {
     display: inline-block;
     position: relative;
     left: 0.3rem;
     width: 0;
     font-size: 65%;
     top: -0.15rem;
  }
  .soft-required label::after {
     content: '⬤';
  }
  .hard-required label::after {
     content: '⬤';
  }
  .invalid-feedback {
     color: #a94442;
     display: none;
  }
  .was-validated :invalid~.invalid-feedback,
  .was-validated .is-invalid~.invalid-feedback {
    color: #a94442;
    display: block;
  }
  .was-validated :valid~.valid-feedback,
  .was-validated .is-valid~.valid-feedback {
    display: block;
  }
</style>
[% BLOCK backend_jsinclude %]
<script>
  // Require a username and branch selection
  document.addEventListener('DOMContentLoaded', function(){

      var fieldmap = [% whole.field_map_json %];

      [% INCLUDE "${cwd}/shared-includes/create.js" %]
      [% INCLUDE "${cwd}/shared-includes/crossref.js" %]

  });
  //]]>
</script>
[% END %]
