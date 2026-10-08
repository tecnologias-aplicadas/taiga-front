###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "navigationBarDirective", () ->
    scope = compile = provide = null
    mocks = {}
    template = "<div tg-navigation-bar></div>"
    projects = Immutable.fromJS({
        recents: [
            {id: 1},
            {id: 2},
            {id: 3}
        ]
    })

    createDirective = () ->
        elm = compile(template)(scope)
        return elm

    _mocksCurrentUserService = () ->
        mocks.currentUserService = {
            projects: projects
            isAuthenticated: sinon.stub()
            getUser: sinon.stub()
        }

        provide.value "tgCurrentUserService", mocks.currentUserService

    _mocksLocationService = () ->
        mocks.locationService = {
            url: sinon.stub()
            search: sinon.stub()
        }

        provide.value "$tgLocation", mocks.locationService

    _mocksConfig = () ->
        mocks.config =  Immutable.fromJS({
            publicRegisterEnabled: true
        })

        provide.value "$tgConfig", mocks.config

    _mockTgNavUrls = () ->
        mocks.navUrls = {
            resolve: sinon.stub()
        }
        provide.value "$tgNavUrls", mocks.navUrls

    _mockTranslateFilter = () ->
        mockTranslateFilter = (value) ->
            return value
        provide.value "translateFilter", mockTranslateFilter

    _mockTgDropdownProjectListDirective = () ->
        provide.factory 'tgDropdownProjectListDirective', () -> {}

    _mockTgDropdownUserDirective = () ->
        provide.factory 'tgDropdownUserDirective', () -> {}

    _mockTgDropdownNotificationsDirective = () ->
        provide.factory 'tgDropdownNotificationsDirective', () -> {}

    _mockTgFeedbackService = () ->
        mocks.feedbackService = {
            sendFeedback: sinon.stub()
        }
        provide.value "tgFeedbackService", mocks.feedbackService

    _mocks = () ->
        module ($provide) ->
            provide = $provide

            _mocksCurrentUserService()
            _mocksLocationService()
            _mockTgNavUrls( )
            _mockTranslateFilter()
            _mockTgDropdownProjectListDirective()
            _mockTgDropdownUserDirective()
            _mockTgDropdownNotificationsDirective()
            _mocksConfig()
            _mockTgFeedbackService()

            return null

    beforeEach ->
        module "templates"
        module "taigaNavigationBar"

        _mocks()

        inject ($rootScope, $compile) ->
            scope = $rootScope.$new()
            compile = $compile

        recents = Immutable.fromJS([
            {
                id:1
            },
            {
                id: 2
            }
        ])

    it "navigation bar directive scope content", () ->
        elm = createDirective()
        scope.$apply()
        expect(elm.isolateScope().vm.projects.size).to.be.equal(3)

        mocks.currentUserService.isAuthenticated.returns(true)

        expect(elm.isolateScope().vm.isAuthenticated).to.be.true

    it "navigation bar login", () ->
        mocks.navUrls.resolve.withArgs("login").returns("/login")
        nextUrl = "/discover/search?order_by=-total_activity_last_month"
        mocks.locationService.url.returns(nextUrl)
        elm = createDirective()
        scope.$apply()
        vm = elm.isolateScope().vm
        expect(mocks.locationService.url.callCount).to.be.equal(0)
        expect(mocks.locationService.search.callCount).to.be.equal(0)
        vm.login()
        expect(mocks.locationService.url.callCount).to.be.equal(2)
        expect(mocks.locationService.search.callCount).to.be.equal(1)
        expect(mocks.locationService.url.calledWith("/login")).to.be.true
        expect(mocks.locationService.search.calledWith({next: encodeURIComponent(nextUrl)})).to.be.true
        expect(vm.publicRegisterEnabled).to.be.true

    it "dropdown help send feedback", () ->
        elm = createDirective()
        scope.$apply()
        vm = elm.isolateScope().vm
        expect(mocks.feedbackService.sendFeedback.callCount).to.be.equal(0)
        vm.sendFeedback()
        expect(mocks.feedbackService.sendFeedback.callCount).to.be.equal(1)

    it "logo do usuário autenticado leva ao painel pela rota relativa, sem host", () ->
        inject (tgNavigationBarService) -> tgNavigationBarService.enableHeader()
        mocks.currentUserService.isAuthenticated.returns(true)
        elm = createDirective()
        scope.$apply()
        logo = elm.find("a.logo")
        expect(logo.length).to.be.equal(1)
        expect(logo.attr("tg-nav")).to.be.equal("dashboard")
        expect(logo.attr("href")).not.to.match(/^(https?:)?\/\//)

    it "logo de quem não está autenticado leva à home pública, sem host", () ->
        inject (tgNavigationBarService) -> tgNavigationBarService.enableHeader()
        mocks.currentUserService.isAuthenticated.returns(false)
        elm = createDirective()
        scope.$apply()
        logo = elm.find("a.logo")
        expect(logo.length).to.be.equal(1)
        expect(logo.attr("tg-nav")).to.be.equal("home")
        expect(logo.attr("href")).not.to.match(/^(https?:)?\/\//)

    it "superusuário vê o ícone do carrossel à esquerda do guia de story points", () ->
        inject (tgNavigationBarService) -> tgNavigationBarService.enableHeader()
        mocks.currentUserService.isAuthenticated.returns(true)
        mocks.currentUserService.getUser.returns(Immutable.fromJS({is_superuser: true}))
        elm = createDirective()
        scope.$apply()
        wrapper = elm.find(".news-admin-wrapper")
        expect(wrapper.length).to.be.equal(1)
        expect(wrapper.find("a").attr("tg-nav")).to.be.equal("news-admin")
        expect(wrapper.next().hasClass("story-points-guide-wrapper")).to.be.true

    it "quem não é superusuário não vê o ícone do carrossel", () ->
        inject (tgNavigationBarService) -> tgNavigationBarService.enableHeader()
        mocks.currentUserService.isAuthenticated.returns(true)
        mocks.currentUserService.getUser.returns(Immutable.fromJS({is_superuser: false}))
        elm = createDirective()
        scope.$apply()
        expect(elm.find(".news-admin-wrapper").length).to.be.equal(0)
        expect(elm.find(".story-points-guide-wrapper").length).to.be.equal(1)
