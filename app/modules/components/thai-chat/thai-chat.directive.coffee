###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

ThaiChatDirective = () ->
    link = (scope, el) ->
        # Foca no textarea ao abrir o painel
        textarea = el[0].querySelector("textarea")
        textarea?.focus()

    return {
        link: link,
        controller: "ThaiChatCtrl",
        bindToController: true,
        scope: {
            onClose: "&"
        },
        controllerAs: "vm",
        templateUrl: "components/thai-chat/thai-chat.html"
    }

angular.module("taigaComponents").directive("tgThaiChat", ThaiChatDirective)