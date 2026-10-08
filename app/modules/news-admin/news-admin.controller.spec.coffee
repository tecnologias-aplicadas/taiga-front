###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "NewsAdminController", ->
    controller = $q = $rootScope = null
    mocks = {}

    _mocks = ->
        module ($provide) ->
            mocks.rs = {
                news: {
                    NEWS_SLIDE_MAX_IMAGE_SIZE: 2 * 1024 * 1024
                    list: sinon.stub()
                    create: sinon.stub()
                    update: sinon.stub()
                    changeImage: sinon.stub()
                    remove: sinon.stub()
                    bulkUpdateOrder: sinon.stub()
                }
            }
            mocks.currentUserService = {getUser: sinon.stub()}
            mocks.errorHandlingService = {permissionDenied: sinon.stub()}
            mocks.confirm = {askOnDelete: sinon.stub(), notify: sinon.stub()}
            mocks.translate = {instant: sinon.stub().returnsArg(0)}
            mocks.lightbox = {open: sinon.stub(), close: sinon.stub()}

            $provide.value "$tgResources", mocks.rs
            $provide.value "tgCurrentUserService", mocks.currentUserService
            $provide.value "tgErrorHandlingService", mocks.errorHandlingService
            $provide.value "$tgConfirm", mocks.confirm
            $provide.value "$translate", mocks.translate
            $provide.value "lightboxService", mocks.lightbox
            return null

    beforeEach ->
        module "taigaNewsAdmin"
        _mocks()
        inject ($controller, _$q_, _$rootScope_) ->
            controller = $controller
            $q = _$q_
            $rootScope = _$rootScope_

    slides = () ->
        return [
            {id: 1, title: "A", description: "", order: 0, is_active: true, image_url: "http://x/1.png"},
            {id: 2, title: "B", description: "", order: 1, is_active: false, image_url: "http://x/2.png"},
            {id: 3, title: "C", description: "", order: 2, is_active: true, image_url: "http://x/3.png"}
        ]

    createAsSuperuser = () ->
        mocks.currentUserService.getUser.returns(Immutable.fromJS({is_superuser: true}))
        mocks.rs.news.list.returns($q.resolve(slides()))
        ctrl = controller "NewsAdmin", {$scope: {}}
        $rootScope.$apply()
        return ctrl

    it "quem não é superusuário cai em permissão negada e não carrega a lista", ->
        mocks.currentUserService.getUser.returns(Immutable.fromJS({is_superuser: false}))
        ctrl = controller "NewsAdmin", {$scope: {}}
        expect(ctrl.isAdmin).to.be.false
        expect(mocks.errorHandlingService.permissionDenied).to.be.calledOnce
        expect(mocks.rs.news.list.callCount).to.be.equal(0)

    it "superusuário carrega todos os slides, inclusive inativos", ->
        ctrl = createAsSuperuser()
        expect(ctrl.isAdmin).to.be.true
        expect(mocks.errorHandlingService.permissionDenied.callCount).to.be.equal(0)
        expect(_.map(ctrl.slides, "id")).to.be.deep.equal([1, 2, 3])
        expect(ctrl.loading).to.be.false

    it "criar chama o recurso com os dados e o arquivo, e limpa o formulário", ->
        ctrl = createAsSuperuser()
        mocks.rs.news.create.returns($q.resolve({id: 4}))
        file = {name: "slide.png", size: 1000}
        ctrl.selectImage([file])
        ctrl.form.title = "  Novo  "
        ctrl.form.description = "Desc"
        ctrl.form.order = 5

        ctrl.create()
        $rootScope.$apply()

        expect(mocks.rs.news.create).to.be.calledWith({title: "Novo", description: "Desc", order: 5}, file)
        expect(ctrl.form.title).to.be.equal("")
        expect(ctrl.form.file).to.be.null
        expect(ctrl.formError).to.be.null
        expect(mocks.rs.news.list).to.be.calledTwice

    it "criar sem imagem ou sem título é barrado na tela, sem chamar o servidor", ->
        ctrl = createAsSuperuser()
        ctrl.form.title = "T"
        ctrl.create()
        expect(ctrl.formError).to.be.equal("NEWS_ADMIN.ERRORS.IMAGE_REQUIRED")

        ctrl.selectImage([{name: "s.png", size: 10}])
        ctrl.form.title = "   "
        ctrl.create()
        expect(ctrl.formError).to.be.equal("NEWS_ADMIN.ERRORS.TITLE_REQUIRED")
        expect(mocks.rs.news.create.callCount).to.be.equal(0)

    it "expõe o nome do arquivo escolhido para a tela, no novo slide e na edição", ->
        ctrl = createAsSuperuser()
        ctrl.selectImage([{name: "banner.png", size: 10}])
        expect(ctrl.form.fileName).to.be.equal("banner.png")
        ctrl.selectImage([])
        expect(ctrl.form.fileName).to.be.null

        ctrl.startEdit(ctrl.slides[0])
        expect(ctrl.editing.fileName).to.be.null
        ctrl.selectEditImage([{name: "novo.png", size: 10}])
        expect(ctrl.editing.fileName).to.be.equal("novo.png")

    it "imagem acima de 2 MB avisa já ao escolher", ->
        ctrl = createAsSuperuser()
        ctrl.selectImage([{name: "big.png", size: 2 * 1024 * 1024 + 1}])
        expect(ctrl.formError).to.be.equal("NEWS_ADMIN.ERRORS.IMAGE_TOO_LARGE")

    it "erro 400 do servidor vira mensagem traduzida sem quebrar, e libera o envio", ->
        ctrl = createAsSuperuser()
        mocks.rs.news.create.returns($q.reject({status: 400, data: {title: ["title_too_long"]}}))
        ctrl.selectImage([{name: "s.png", size: 10}])
        ctrl.form.title = "T"

        ctrl.create()
        expect(ctrl.saving).to.be.true
        $rootScope.$apply()

        expect(ctrl.formError).to.be.equal("NEWS_ADMIN.ERRORS.TITLE_TOO_LONG")
        expect(ctrl.saving).to.be.false

    it "código desconhecido e 403 viram mensagens genérica e de permissão", ->
        ctrl = createAsSuperuser()
        expect(ctrl.errorMessage({status: 400, data: {image: ["whatever"]}})).to.be.equal("NEWS_ADMIN.ERRORS.GENERIC")
        expect(ctrl.errorMessage({status: 500, data: "texto"})).to.be.equal("NEWS_ADMIN.ERRORS.GENERIC")
        expect(ctrl.errorMessage({status: 403, data: {}})).to.be.equal("NEWS_ADMIN.ERRORS.FORBIDDEN")
        expect(ctrl.errorMessage({status: 400, data: {code: "slide_not_found"}})).to.be.equal("NEWS_ADMIN.ERRORS.SLIDE_NOT_FOUND")

    it "descer um slide reordena na tela e envia a lista inteira numa única chamada", ->
        ctrl = createAsSuperuser()
        mocks.rs.news.bulkUpdateOrder.returns($q.resolve({}))

        ctrl.moveDown(0)
        $rootScope.$apply()

        expect(mocks.rs.news.bulkUpdateOrder).to.be.calledOnce
        expect(mocks.rs.news.bulkUpdateOrder).to.be.calledWith([
            {slide_id: 2, order: 0}, {slide_id: 1, order: 1}, {slide_id: 3, order: 2}
        ])
        expect(_.map(ctrl.slides, "order")).to.be.deep.equal([0, 1, 2])
        expect(ctrl.saving).to.be.false

        ctrl.moveUp(0)
        ctrl.moveDown(2)
        expect(mocks.rs.news.bulkUpdateOrder).to.be.calledOnce

    it "ativar e desativar usam PATCH com is_active", ->
        ctrl = createAsSuperuser()
        mocks.rs.news.update.returns($q.resolve({is_active: false}))
        ctrl.toggleActive(ctrl.slides[0])
        $rootScope.$apply()
        expect(mocks.rs.news.update).to.be.calledWith(1, {is_active: false})
        expect(ctrl.slides[0].is_active).to.be.false

    it "editar abre a lightbox com os dados do slide e o fechamento limpa a edição", ->
        ctrl = createAsSuperuser()
        ctrl.startEdit(ctrl.slides[1])

        expect(mocks.lightbox.open).to.be.calledOnce
        expect(mocks.lightbox.open.firstCall.args[0]).to.be.equal(".lightbox-news-slide-edit")
        expect(ctrl.editing).to.be.deep.equal({id: 2, title: "B", description: "", order: 1, file: null, fileName: null})

        onClose = mocks.lightbox.open.firstCall.args[1]
        onClose()
        expect(ctrl.editing).to.be.null
        expect(ctrl.editError).to.be.null

    it "cancelar fecha a lightbox", ->
        ctrl = createAsSuperuser()
        ctrl.startEdit(ctrl.slides[0])
        ctrl.cancelEdit()
        expect(mocks.lightbox.close).to.be.calledWith(".lightbox-news-slide-edit")

    it "salvar envia texto por JSON e, se houver arquivo, troca a imagem; fecha e recarrega", ->
        ctrl = createAsSuperuser()
        mocks.rs.news.update.returns($q.resolve({}))
        mocks.rs.news.changeImage.returns($q.resolve({}))
        ctrl.startEdit(ctrl.slides[1])
        ctrl.editing.title = "B2"
        file = {name: "n.png", size: 10}
        ctrl.selectEditImage([file])

        ctrl.saveEdit()
        $rootScope.$apply()

        expect(mocks.rs.news.update).to.be.calledWith(2, {title: "B2", description: "", order: 1})
        expect(mocks.rs.news.changeImage).to.be.calledWith(2, file)
        expect(mocks.lightbox.close).to.be.calledWith(".lightbox-news-slide-edit")
        expect(mocks.rs.news.list).to.be.calledTwice
        expect(ctrl.saving).to.be.false

    it "erro ao salvar mantém a lightbox aberta com a mensagem", ->
        ctrl = createAsSuperuser()
        mocks.rs.news.update.returns($q.reject({status: 400, data: {title: ["title_too_long"]}}))
        ctrl.startEdit(ctrl.slides[0])
        ctrl.saveEdit()
        $rootScope.$apply()
        expect(mocks.lightbox.close.callCount).to.be.equal(0)
        expect(ctrl.editError).to.be.equal("NEWS_ADMIN.ERRORS.TITLE_TOO_LONG")
        expect(ctrl.editing).not.to.be.null

    it "excluir pede confirmação e só então chama o recurso", ->
        ctrl = createAsSuperuser()
        askResponse = {finish: sinon.stub()}
        mocks.confirm.askOnDelete.returns($q.resolve(askResponse))
        mocks.rs.news.remove.returns($q.resolve({}))

        ctrl.remove(ctrl.slides[2])
        $rootScope.$apply()

        expect(mocks.confirm.askOnDelete).to.be.calledWith("NEWS_ADMIN.DELETE_TITLE", "C")
        expect(mocks.rs.news.remove).to.be.calledWith(3)
        expect(askResponse.finish).to.be.calledOnce

    describe "retorno visual pelo mecanismo de notificação do Taiga", ->
        it "criar notifica sucesso", ->
            ctrl = createAsSuperuser()
            mocks.rs.news.create.returns($q.resolve({id: 4}))
            ctrl.selectImage([{name: "s.png", size: 10}])
            ctrl.form.title = "T"
            ctrl.create()
            $rootScope.$apply()
            expect(mocks.confirm.notify).to.be.calledWithExactly("success")

        it "salvar a edição notifica sucesso", ->
            ctrl = createAsSuperuser()
            mocks.rs.news.update.returns($q.resolve({}))
            ctrl.startEdit(ctrl.slides[0])
            ctrl.saveEdit()
            $rootScope.$apply()
            expect(mocks.confirm.notify).to.be.calledWithExactly("success")

        it "ativar e desativar notificam cada estado", ->
            ctrl = createAsSuperuser()
            mocks.rs.news.update.returns($q.resolve({is_active: false}))
            ctrl.toggleActive(ctrl.slides[0])
            $rootScope.$apply()
            expect(mocks.confirm.notify).to.be.calledWithExactly("success")

            mocks.rs.news.update.returns($q.resolve({is_active: true}))
            ctrl.toggleActive(ctrl.slides[1])
            $rootScope.$apply()
            expect(mocks.confirm.notify).to.be.calledWithExactly("success")

        it "reordenar notifica sucesso", ->
            ctrl = createAsSuperuser()
            mocks.rs.news.bulkUpdateOrder.returns($q.resolve({}))
            ctrl.moveDown(0)
            $rootScope.$apply()
            expect(mocks.confirm.notify).to.be.calledWithExactly("success")

        it "excluir notifica sucesso", ->
            ctrl = createAsSuperuser()
            mocks.confirm.askOnDelete.returns($q.resolve({finish: sinon.stub()}))
            mocks.rs.news.remove.returns($q.resolve({}))
            ctrl.remove(ctrl.slides[2])
            $rootScope.$apply()
            expect(mocks.confirm.notify).to.be.calledWithExactly("success")

        it "erro não notifica sucesso", ->
            ctrl = createAsSuperuser()
            mocks.rs.news.create.returns($q.reject({status: 400, data: {title: ["title_required"]}}))
            ctrl.selectImage([{name: "s.png", size: 10}])
            ctrl.form.title = "T"
            ctrl.create()
            $rootScope.$apply()
            expect(mocks.confirm.notify.callCount).to.be.equal(0)
