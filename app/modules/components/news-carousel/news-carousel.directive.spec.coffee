###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgNewsCarousel", () ->
    scope = compile = $q = $timeout = null
    mocks = {}

    beforeEach ->
        module "templates"
        module "taigaComponents"

        module ($provide) ->
            mocks.rs = {news: {list: sinon.stub()}}
            $provide.value "$tgResources", mocks.rs
            $provide.value "translateFilter", (value) -> value
            return null

        inject ($rootScope, $compile, _$q_, _$timeout_) ->
            scope = $rootScope.$new()
            compile = $compile
            $q = _$q_
            $timeout = _$timeout_

    render = () ->
        elm = compile("<tg-news-carousel></tg-news-carousel>")(scope)
        scope.$apply()
        $timeout.flush()
        return elm

    titles = (elm) ->
        return _.map(elm.find(".hl-cw-slide-title"), (node) -> $(node).text())

    it "renderiza três slides na ordem recebida, com clones nas pontas para o loop", () ->
        mocks.rs.news.list.returns($q.resolve([
            {id: 1, title: "Primeiro", description: "d1", image_url: "http://x/1.png", order: 1},
            {id: 2, title: "Segundo", description: "d2", image_url: "http://x/2.png", order: 2},
            {id: 3, title: "Terceiro", description: "d3", image_url: "http://x/3.png", order: 3}
        ]))
        elm = render()
        vm = elm.isolateScope().vm

        expect(_.map(vm.slides, "title")).to.be.deep.equal(["Primeiro", "Segundo", "Terceiro"])
        expect(titles(elm)).to.be.deep.equal(["Terceiro", "Primeiro", "Segundo", "Terceiro", "Primeiro"])
        expect(elm.find(".hl-cw-dot").length).to.be.equal(3)
        expect(elm.find(".hl-cw-dot--active").length).to.be.equal(1)
        expect(elm.find(".hl-cw-counter").text().replace(/\s+/g, " ").trim()).to.be.equal("1 / 3")
        expect(elm.find("img").first().attr("alt")).to.be.equal("Terceiro")
        expect(elm.find("section.hl-news").length).to.be.equal(1)
        expect(elm.find(".hl-section-header [translate='HOME_LANDING.NEWS_TITLE']").length).to.be.equal(1)

        vm.next()
        scope.$apply()
        expect(vm.current).to.be.equal(1)
        expect(elm.find(".hl-cw-dot").eq(1).hasClass("hl-cw-dot--active")).to.be.true

        vm.go(-1)
        expect(vm.current).to.be.equal(2)

    it "sem slide ativo a seção de novidades inteira some, sem mensagem", () ->
        mocks.rs.news.list.returns($q.resolve([]))
        elm = render()
        expect(elm.find("section.hl-news").length).to.be.equal(0)
        expect(elm.find(".hl-section-header").length).to.be.equal(0)
        expect(elm.find(".hl-cw-stage").length).to.be.equal(0)
        expect(elm.find(".hl-cw-nav-zone").length).to.be.equal(0)
        expect(elm.text().trim()).to.be.equal("")

    it "com erro do servidor a seção some sem lançar erro", () ->
        mocks.rs.news.list.returns($q.reject({status: 500}))
        elm = null
        expect(() -> elm = render()).not.to.throw()
        expect(elm.find("section.hl-news").length).to.be.equal(0)
        expect(elm.text().trim()).to.be.equal("")
        expect(elm.isolateScope().vm.total).to.be.equal(0)

    it "enquanto carrega nada aparece (sem flash do cabeçalho)", () ->
        deferred = $q.defer()
        mocks.rs.news.list.returns(deferred.promise)
        elm = compile("<tg-news-carousel></tg-news-carousel>")(scope)
        scope.$apply()
        expect(elm.find("section.hl-news").length).to.be.equal(0)
        deferred.resolve([{id: 1, title: "Um", description: "", image_url: "http://x/1.png", order: 1}])
        scope.$apply()
        $timeout.flush()
        expect(elm.find("section.hl-news").length).to.be.equal(1)

    it "título com HTML aparece como texto", () ->
        mocks.rs.news.list.returns($q.resolve([
            {id: 1, title: "<b>negrito</b>", description: "<i>x</i>", image_url: "http://x/1.png", order: 1}
        ]))
        elm = render()
        title = elm.find(".hl-cw-slide-title").first()
        expect(title.text()).to.be.equal("<b>negrito</b>")
        expect(title.find("b").length).to.be.equal(0)
        expect(elm.find(".hl-cw-slide-desc").first().find("i").length).to.be.equal(0)
