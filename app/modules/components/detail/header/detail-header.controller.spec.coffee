###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "DetailHeaderComponent", ->
    DetailHeaderCtrl =  null
    provide = null
    controller = null
    rootScope = null
    mocks = {}

    _mockRootScope = () ->
        mocks.rootScope = {
            $broadcast: sinon.stub()
        }

        provide.value "$rootScope", mocks.rootScope

    _mockTgConfirm = () ->
        mocks.tgConfirm = {
            notify: sinon.stub()
        }

        provide.value "$tgConfirm", mocks.tgConfirm

    _mockTgQueueModelTransformation = () ->
        mocks.modelTransform = {
            save: sinon.stub()
        }

        provide.value "$tgQueueModelTransformation", mocks.tgQueueModelTransformation

    _mockWindow = () ->
        mocks.window = {
            getSelection: sinon.stub()
        }

        provide.value "$window", mocks.window

    _mockEditingTracker = () ->
        mocks.editingTracker = {
            begin: sinon.stub()
            end: sinon.stub()
        }

        provide.value "tgEditingTracker", mocks.editingTracker

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockRootScope()
            _mockTgConfirm()
            _mockTgQueueModelTransformation()
            _mockWindow()
            _mockEditingTracker()

            return null

    beforeEach ->
        module "taigaBase"

        _mocks()

        inject ($controller) ->
            controller = $controller

            DetailHeaderCtrl = controller "DetailHeaderCtrl", {}, {
                item: {
                    subject: 'Example subject'
                }
            }

        DetailHeaderCtrl.originalSubject = DetailHeaderCtrl.item.subject

    it "check permissions", () ->
        DetailHeaderCtrl.project = {
            my_permissions: ['view_us']
        }
        DetailHeaderCtrl.requiredPerm = 'view_us'
        DetailHeaderCtrl._checkPermissions()
        expect(DetailHeaderCtrl.permissions).to.be.eql({canEdit: true})

    it "edit subject without selection", () ->
        mocks.window.getSelection.returns({
            type: 'Range'
        })
        DetailHeaderCtrl.editSubject(true)
        expect(DetailHeaderCtrl.editMode).to.be.false

    it "edit subject on click", () ->
        mocks.window.getSelection.returns({
            type: 'potato'
        })
        DetailHeaderCtrl.editSubject(true)
        expect(DetailHeaderCtrl.editMode).to.be.true

    it "entrar na edição do assunto marca o campo como em edição", () ->
        mocks.window.getSelection.returns({type: 'potato'})

        DetailHeaderCtrl.editSubject(true)

        expect(mocks.editingTracker.begin).to.have.been.calledOnce
        expect(mocks.editingTracker.end).not.to.have.been.called

    it "cancelar a edição do assunto libera o campo", () ->
        mocks.window.getSelection.returns({type: 'potato'})
        DetailHeaderCtrl.editSubject(true)

        DetailHeaderCtrl.cancelEdit()

        expect(mocks.editingTracker.end).to.have.been.calledOnce
        expect(mocks.editingTracker.end.firstCall.args[0]).to.be.equal(mocks.editingTracker.begin.firstCall.args[0])

    it "salvar o assunto libera o campo", () ->
        mocks.window.getSelection.returns({type: 'potato'})
        DetailHeaderCtrl.modelTransform = {save: sinon.stub().returns({then: sinon.stub()})}
        DetailHeaderCtrl.editSubject(true)

        DetailHeaderCtrl.saveSubject()

        expect(mocks.editingTracker.end).to.have.been.calledOnce

    it "do not edit subject", () ->
        mocks.window.getSelection.returns({
            type: 'Range'
        })
        DetailHeaderCtrl.editSubject(false)
        expect(DetailHeaderCtrl.editMode).to.be.false

    it "save on keydown Enter", () ->
        event = {}
        event.which = 13
        DetailHeaderCtrl.saveSubject = sinon.stub()
        DetailHeaderCtrl.onKeyDown(event)
        expect(DetailHeaderCtrl.saveSubject).have.been.called

    it "don't save on keydown ESC", () ->
        event = {}
        event.which = 27
        DetailHeaderCtrl.editSubject = sinon.stub()
        DetailHeaderCtrl.onKeyDown(event)
        expect(DetailHeaderCtrl.item.subject).to.be.equal(DetailHeaderCtrl.originalSubject)
        expect(DetailHeaderCtrl.editSubject).have.been.calledWith(false)
