[% USE Koha %]
[% USE Asset %]
[% USE raw %]
[% SET koha_version = Koha.Version %]

[% SET cwd = whole.cwd %]
[% PROCESS "${cwd}/shared-includes/form.inc" %]
[% SET staff = 1 %]
[% SET requests_back_url = '/cgi-bin/koha/ill/ill-requests.pl' %]

[% IF whole.error %]
  [% IF whole.status == 'missing_fields' %]
    <p><em>Please Note:</em> Some mandatory fields are missing.</p>
  [% ELSIF whole.status == 'missing_branch' %]
    <p><em>Please Note:</em> Branch is a mandatory field.</p>
  [% ELSIF whole.status == 'invalid_borrower' %]
    <p><em>Please Note:</em> The borrower details you entered are invalid.</p>
  [% ELSIF whole.status == 'invalid_branch' %]
    <p><em>Please Note:</em> The branch you chose is invalid.</p>
  [% ELSIF whole.status == 'api' %]
    <p><em>Please Note:</em> there was an error whilst communicating with the remote service.</p>
  [% ELSIF whole.status == 'missing_query' %]
    <p><em>Please Note:</em> You did not enter a search query.</p>
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
   <li role="presentation" class="active"><a href="#type-book" aria-controls="type-book" role="tab" data-toggle="tab">Book</a></li>
   <li role="presentation"><a href="#type-article" aria-controls="type-article" role="tab" data-toggle="tab">Article</a></li>
   <li role="presentation"><a href="#type-chapter" aria-controls="type-chapter" role="tab" data-toggle="tab">Chapter</a></li>
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
  #rapid_warnings {
    margin-bottom: 0;
  }
  .rapid_hint {
   margin-left: 1em;
  }
  .alert {
    margin-top: 20px;
  }
  #localholdings,
  #errormessage {
    margin-top: 1rem;
  }
  #localholdings ul {
    margin-top: 0.5rem;
  }
  #localholdings li {
    margin: 0.3rem 0;
  }
</style>
[% BLOCK backend_jsinclude %]
<script>
  // Require a username and branch selection
  document.addEventListener('DOMContentLoaded', function(){

      var listenerSelectors = '';

      var fieldmap = [% whole.field_map_json %];

      [% INCLUDE "${cwd}/shared-includes/create.js" %]


      let hasValidate = false;

      const doSubmit = (event, form, formId, type) => {
          const messages = validateFields(form, type);
          const container = document.getElementById(type + '_messages');
          for (const c of container.children) {
              c.remove();
          }
          if (messages) {
              hasValidated = true;
              event.preventDefault();
              event.stopPropagation();
              const hb = document.createElement("div");
              hb.classList.add("has-error");
              hb.classList.add("has-feedback");
              const ul = document.createElement("ul");
              ul.classList.add("help-block");
              hb.append(ul);
              container.append(hb);
              for (const message of messages) {
                  const li = document.createElement("li");
                  li.append(message);
                  ul.append(li);
              }
          }
      };

      const initForm = (form, formId, type) => {
          const id = '#' + formId + ' #cardnumber';
          [% IF koha_version.major <= 22 && koha_version.minor < 11 %]
          $(id).autocomplete({
              source: "/cgi-bin/koha/circ/ysearch.pl",
              minLength: 3,
              select: function( event, ui ) {
                  var field = ui.item.cardnumber;
                  $(id).val(field)
                  return false;
              }
          })
              .data( "ui-autocomplete" )._renderItem = function( ul, item ) {
                  return $( "<li></li>" )
                      .data( "ui-autocomplete-item", item )
                      .append( "<a>" + item.surname + ", " + item.firstname + " (" + item.cardnumber + ") <small>" + item.address + " " + item.city + " " + item.zipcode + " " + item.country + "</small></a>" )
                      .appendTo( ul );
              };
          [% ELSE %]
          patron_autocomplete(
              $(id),
              {
                  'on-select-callback': function( event, ui ) {
                      $(id).val( ui.item.cardnumber );
                      return false;
                  }
              }


          );
          [% END %]
          form.addEventListener('submit', (event) => doSubmit(event, form, formId, type));
      };

      for (const type of ['Book', 'Article', 'BookChapter']) {
          for (const o of ['create', 'edit']) {
              const formId = type + '_' + o + '_form';
              const form = document.getElementById(formId);
              if (form) {
                  initForm(form, formId, type);
              }
          }
      }
  });
  //]]>
</script>
[% END %]
