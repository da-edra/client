// @flow
import * as React from 'react'
import {globalStyles, globalColors, globalMargins} from '../../styles'
import {Box, Icon, Text} from '../../common-adapters'
import AddNew from './add-new-container'
import ConnectedFilesBanner from '../banner/fileui-banner/container'
import Breadcrumb from './breadcrumb-container.desktop'
import {type FolderHeaderProps} from './header'

const FolderHeader = ({path, openInFileUI, onChat}: FolderHeaderProps) => (
  <Box style={styleHeaderContainer}>
    <Box style={styleFolderHeader}>
      {path === '/keybase' ? (
        <Box style={folderHeaderStyleRoot}>
          <Text type="BodyBig">Keybase Files</Text>
        </Box>
      ) : (
        <Box style={styleFolderHeaderContainer}>
          <Breadcrumb path={path} />
          <Box style={styleFolderHeaderEnd}>
            <AddNew path={path} style={styleAddNew} />
            <Icon type="iconfont-finder" color={globalColors.black_40} fontSize={16} onClick={openInFileUI} />
            {onChat && (
              <Icon
                type="iconfont-chat"
                style={{
                  marginLeft: globalMargins.small,
                }}
                color={globalColors.black_40}
                fontSize={16}
                onClick={onChat}
              />
            )}
          </Box>
        </Box>
      )}
    </Box>
    <ConnectedFilesBanner path={path} />
  </Box>
)

const stylesCommonRow = {
  ...globalStyles.flexBoxRow,
  alignItems: 'center',
}

const styleHeaderContainer = {
  ...globalStyles.flexBoxColumn,
  width: '100%',
}

const styleFolderHeader = {
  minHeight: 48,
}

const folderHeaderStyleRoot = {
  ...stylesCommonRow,
  justifyContent: 'center',
  width: '100%',
  height: 48,
}

const styleFolderHeaderEnd = {
  ...stylesCommonRow,
  alignItems: 'center',
  paddingLeft: 16,
  paddingRight: 16,
  flexShrink: 0,
}

const styleFolderHeaderContainer = {
  ...stylesCommonRow,
  width: '100%',
  height: 48,
  alignItems: 'center',
  position: 'relative',
}

const styleAddNew = {
  ...globalStyles.flexBoxRow,
  alignItems: 'center',
  paddingTop: globalMargins.tiny,
  paddingBottom: globalMargins.tiny,
  paddingRight: globalMargins.small - 4,
  paddingLeft: globalMargins.small,
}

export default FolderHeader
