// Build the groups used for validation
function buildValidationGroups(type) {
    const groups = new Map();
    for (const field of Object.keys(fieldmap)) {
        const f = fieldmap[field];
        if (f.required && f.required[type] && f.required[type].group) {
            const group = f.required[type].group;
            const g0 = groups.get(group);
            if (!g0) {
                groups.set(group, [field]);
            } else {
                g0.push(field);
            }
        }
    }
    return groups;
};

// Does a given group of fields have at least one populated input?
function isGroupValid(fields, inputs) {
    return fields.findIndex(function (field) {
        const input = inputs.get(field);
        if (input && input.value.length > 0) {
            return true;
        }
        return false;
    }) >= 0;

};

// Validate fields and display warnings
function validateFields(form, type) {
    const inputs = new Map();
    for (const input of form.getElementsByTagName('input')) {
        const name = input.getAttribute('name');
        inputs.set(name, input);
    }
    // Get our validation groups
    const messages = [];
    const errorFields = new Set();
    const groups = buildValidationGroups(type);
    for (const fields of groups.values()) {
        if (!isGroupValid(fields, inputs)) {
            const fieldNames = fields.map(function (field) {
                errorFields.add(field);
                return typeof fieldmap[field].label === 'object' ?
                    fieldmap[field].label[type] :
                    fieldmap[field].label;
            });
            messages.push(
                "[% MSG.you_must_complete_fields %] " + fieldNames.join(', ')
            );
        }
    }

    for (const name of inputs.keys()) {
        if (errorFields.has(name)) {
            inputs.get(name).parentElement.classList.add("has-error");
            inputs.get(name).classList.add("is-invalid");
        } else {
            inputs.get(name).parentElement.classList.remove("has-error");
            inputs.get(name).classList.remove("is-invalid");
        }
    }
    return messages;
};

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
        hb.classList.add("text-danger");
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
    if (typeof patron_autocomplete === "function") {
        patron_autocomplete(
            $(id),
            {
                'on-select-callback': function( event, ui ) {
                    $(id).val( ui.item.cardnumber );
                    return false;
                }
            }


        );
    }
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
