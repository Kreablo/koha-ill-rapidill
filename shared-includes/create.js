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
                _("You must complete at least one of the following fields: ") + fieldNames.join(', ')
            );
        }
    }

    for (const name of inputs.keys()) {
        if (errorFields.has(name)) {
            inputs.get(name).parentElement.classList.add("has-error");
        } else {
            inputs.get(name).parentElement.classList.remove("has-error");
        }
    }
    return messages;
};
