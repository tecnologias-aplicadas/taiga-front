/*
 * This source code is licensed under the terms of the
 * GNU Affero General Public License found in the LICENSE file in
 * the root directory of this source tree.
 *
 * Copyright (c) 2021-present Kaleidos INC
 */

module.exports = {
    root: true,
    extends: ["stylelint-config-standard"],
    plugins: ["stylelint-order", "stylelint-scss"],
    rules: {
        // [ALTERADO] Desativei a ordem alfabética das propriedades
        "order/properties-alphabetical-order": null, // <-- Linha modificada

        // [ALTERADO] Desativei a verificação de aspas simples
        "string-quotes": null, // <-- Linha modificada

        // [ALTERADO] Desativei a verificação do zero inicial em números decimais
        "number-leading-zero": null, // <-- Linha modificada

        // [ALTERADO] Adicionei @function e @return à lista de at-rules ignoradas
        "at-rule-no-unknown": [
            true,
            {
                ignoreAtRules: [
                    "define-mixin",
                    "mixin",
                    "include",
                    "extend",
                    "each",
                    "for",
                    "function",
                    "return",
                    "if",
                    "else", // <-- Linha modificada
                ],
            },
        ],

        // [ALTERADO] Desativei a verificação de aspas em nomes de fontes
        "font-family-name-quotes": null, // <-- Linha modificada (era 'always-unless-keyword')

        // [ALTERADO] Desativei a proibição de cores hex
        "color-no-hex": null, // <-- Linha modificada (era 'true')

        // [ALTERADO] Desativei a verificação de seletores desconhecidos (ex: "_")
        "selector-type-no-unknown": null, // <-- Linha modificada (tinha configuração anterior)

        // [ALTERADO] Desativei a verificação de seletores duplicados
        "no-duplicate-selectors": null, // <-- Linha adicionada

        // Mantenha o restante das regras ativas
        "function-url-quotes": "always",
        "selector-attribute-quotes": "always",
        "at-rule-no-vendor-prefix": true,
        "media-feature-name-no-vendor-prefix": true,
        "property-no-vendor-prefix": true,
        "selector-no-vendor-prefix": true,
        "value-no-vendor-prefix": true,
        "max-nesting-depth": 4,
        "selector-max-specificity": "1,2,1",
        "color-named": "never",
        "declaration-no-important": true,
        "declaration-property-unit-whitelist": {
            "font-size": ["rem", "em"],
            "/^animation/": ["s"],
        },
        "selector-max-type": 1,
        "font-weight-notation": "numeric",
        "function-url-no-scheme-relative": true,
        "max-line-length": [
            120,
            {
                ignore: ["comments"],
            },
        ],
        indentation: [4],
        "rule-empty-line-before": null,
        "declaration-empty-line-before": null,
        "no-empty-source": null,
        "selector-combinator-space-after": null,
        "selector-max-type": null,
        "no-descending-specificity": null,
        "max-empty-lines": null,
        "block-closing-brace-empty-line-before": null,
        "selector-max-compound-selectors": 5,
        "block-closing-brace-empty-line-before": null,
        "selector-combinator-space-before": null,
        "at-rule-empty-line-before": null,
        "function-calc-no-unspaced-operator": null,
        "declaration-property-unit-whitelist": null,
        "font-weight-notation": null,
        "font-family-no-missing-generic-family-keyword": null,
    },
};
