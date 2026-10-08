###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "NavigationUrlsService", ->
    navUrls = null

    beforeEach ->
        module "taigaBase"

        inject ($tgNavUrls) ->
            navUrls = $tgNavUrls

    it "painel do usuário resolve para caminho relativo, sem host nem ambiente", ->
        expect(navUrls.resolve("dashboard")).to.be.equal("dashboard")

    it "home pública resolve para a raiz da instância", ->
        expect(navUrls.resolve("home")).to.be.equal("")

    it "nenhuma rota registrada aponta para outro host", ->
        for name, url of navUrls.urls
            expect(url, name).not.to.match(/^(https?:)?\/\//)
