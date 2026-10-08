###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "CommentController", ->
    provide = null
    controller = null
    mocks = {}

    _mockTgCurrentUserService = () ->
        mocks.tgCurrentUserService = {
            getUser: sinon.stub()
        }

        provide.value "tgCurrentUserService", mocks.tgCurrentUserService

    _mockTgCheckPermissionsService = () ->
        mocks.tgCheckPermissionsService = {
            check: sinon.stub()
        }
        provide.value "tgCheckPermissionsService", mocks.tgCheckPermissionsService

    _mockTgLightboxFactory = () ->
        mocks.tgLightboxFactory = {
            create: sinon.stub()
        }

        provide.value "tgLightboxFactory", mocks.tgLightboxFactory

    _mockTgHttp = () ->
        mocks.tgHttp = {
            post: sinon.stub()
            delete: sinon.stub()
        }

        provide.value "$tgHttp", mocks.tgHttp

    _mockTgUrls = () ->
        mocks.tgUrls = {
            resolve: sinon.stub()
        }

        provide.value "$tgUrls", mocks.tgUrls

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgCurrentUserService()
            _mockTgCheckPermissionsService()
            _mockTgLightboxFactory()
            _mockTgHttp()
            _mockTgUrls()
            return null

    beforeEach ->
        module "taigaHistory"
        _mocks()

        inject ($controller) ->
            controller = $controller

        commentsCtrl = controller "CommentCtrl"

        commentsCtrl.comment = "comment"
        commentsCtrl.hiddenDeletedComment = true
        commentsCtrl.commentContent = commentsCtrl.comment

    it "show deleted Comment", () ->
        commentsCtrl = controller "CommentCtrl"
        commentsCtrl.showDeletedComment()
        expect(commentsCtrl.hiddenDeletedComment).to.be.false

    it "hide deleted Comment", () ->
        commentsCtrl = controller "CommentCtrl"

        commentsCtrl.hiddenDeletedComment = false
        commentsCtrl.hideDeletedComment()
        expect(commentsCtrl.hiddenDeletedComment).to.be.true

    it "cancel comment on keyup", () ->
        commentsCtrl = controller "CommentCtrl"
        commentsCtrl.comment = {
            id: 2
        }
        event = {
            keyCode: 27
        }
        commentsCtrl.onEditMode = sinon.stub()
        commentsCtrl.checkCancelComment(event)

        expect(commentsCtrl.onEditMode).have.been.called

    it "can Edit Comment", () ->
        commentsCtrl = controller "CommentCtrl"

        commentsCtrl.user = Immutable.fromJS({
            id: 7
        })

        mocks.tgCurrentUserService.getUser.returns(commentsCtrl.user)

        commentsCtrl.comment = {
            user: {
                pk: 7
            }
        }

        mocks.tgCheckPermissionsService.check.withArgs('modify_project').returns(true)

        canEdit = commentsCtrl.canEditDeleteComment()
        expect(canEdit).to.be.true

    it "cannot Edit Comment", () ->
        commentsCtrl = controller "CommentCtrl"

        commentsCtrl.user = Immutable.fromJS({
            id: 8
        })

        mocks.tgCurrentUserService.getUser.returns(commentsCtrl.user)

        commentsCtrl.comment = {
            user: {
                pk: 7
            }
        }

        mocks.tgCheckPermissionsService.check.withArgs('modify_project').returns(false)

        canEdit = commentsCtrl.canEditDeleteComment()
        expect(canEdit).to.be.false

    it "add reaction when the user has not reacted yet", (done) ->
        commentsCtrl = controller "CommentCtrl"

        mocks.tgCurrentUserService.getUser.returns(Immutable.fromJS({id: 7}))

        commentsCtrl.comment = {
            id: 2
            reactions: {}
        }

        mocks.tgUrls.resolve.withArgs("comment-add-reaction", 2).returns("/comments/2/reactions")
        mocks.tgHttp.post.promise().resolve({})

        commentsCtrl.toggleReaction("thumbsup").then () ->
            expect(mocks.tgHttp.post).have.been.calledWith("/comments/2/reactions", {emoji: "thumbsup"})
            expect(mocks.tgHttp.delete).not.have.been.called
            expect(commentsCtrl.comment.reactions.thumbsup.count).to.be.equal(1)
            expect(commentsCtrl.comment.reactions.thumbsup.users).to.be.eql([7])
            done()

    it "remove reaction when the user has already reacted", (done) ->
        commentsCtrl = controller "CommentCtrl"

        mocks.tgCurrentUserService.getUser.returns(Immutable.fromJS({id: 7}))

        commentsCtrl.comment = {
            id: 2
            reactions: {
                thumbsup: {count: 2, users: [7, 8]}
            }
        }

        mocks.tgUrls.resolve.withArgs("comment-remove-reaction", 2).returns("/comments/2/reactions")
        mocks.tgHttp.delete.promise().resolve({})

        commentsCtrl.toggleReaction("thumbsup").then () ->
            expect(mocks.tgHttp.delete).have.been.calledWith("/comments/2/reactions", {emoji: "thumbsup"})
            expect(mocks.tgHttp.post).not.have.been.called
            expect(commentsCtrl.comment.reactions.thumbsup.count).to.be.equal(1)
            expect(commentsCtrl.comment.reactions.thumbsup.users).to.be.eql([8])
            done()
