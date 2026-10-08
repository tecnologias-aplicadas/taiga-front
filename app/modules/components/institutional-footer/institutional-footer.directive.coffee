###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

# Rodapé institucional compartilhado pela home pública e pela tela de login.
# Com `compact` o rodapé cabe em 72px, reduz os logos e omite a linha de texto.
InstitutionalFooterDirective = () ->
    return {
        restrict: "AE"
        scope: {
            compact: "=?"
        }
        templateUrl: "components/institutional-footer/institutional-footer.html"
    }

angular.module("taigaComponents")
    .directive("tgInstitutionalFooter", [InstitutionalFooterDirective])
