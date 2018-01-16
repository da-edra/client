// @noflow
import * as Constants2 from '../../../../constants/chat2'
import * as Types from '../../../../constants/types/chat2'
import CreateTeamNotice from '.'
import {connect, type TypedState} from '../../../../util/container'
import {navigateAppend} from '../../../../actions/route-tree'
import {type StateProps, type DispatchProps} from './container'

const mapStateToProps = (state: TypedState) => {
  const selectedConversationIDKey = Constants2.getSelectedConversation(state)
  if (!selectedConversationIDKey) {
    throw new Error('no selected conversation')
  }

  return {
    selectedConversationIDKey,
  }
}

const mapDispatchToProps = (dispatch: Dispatch) => ({
  _onShowNewTeamDialog: (conversationIDKey: Types.ConversationIDKey) => {
    dispatch(
      navigateAppend([
        {
          props: {conversationIDKey},
          selected: 'showNewTeamDialog',
        },
      ])
    )
  },
})

const mergeProps = (stateProps: StateProps, dispatchProps: DispatchProps) => ({
  onShowNewTeamDialog: () => dispatchProps._onShowNewTeamDialog(stateProps.selectedConversationIDKey),
})

export default connect(mapStateToProps, mapDispatchToProps, mergeProps)(CreateTeamNotice)
