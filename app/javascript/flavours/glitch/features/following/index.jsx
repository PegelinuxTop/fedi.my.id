import PropTypes from 'prop-types';

import { FormattedMessage } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import { debounce } from 'lodash';

import { Account } from 'flavours/glitch/components/account';
import { TimelineHint } from 'flavours/glitch/components/timeline_hint';
import { AccountHeader } from 'flavours/glitch/features/account_timeline/components/account_header';
import BundleColumnError from 'flavours/glitch/features/ui/components/bundle_column_error';
import { normalizeForLookup } from 'flavours/glitch/reducers/accounts_map';
import { getAccountHidden } from 'flavours/glitch/selectors/accounts';
import { useAppSelector } from 'flavours/glitch/store';

import {
  lookupAccount,
  fetchAccount,
  fetchFollowing,
  expandFollowing,
} from '../../actions/accounts';
import { LoadingIndicator } from '../../components/loading_indicator';
import ScrollableList from '../../components/scrollable_list';
import ProfileColumnHeader from '../account/components/profile_column_header';
import { LimitedAccountHint } from '../account_timeline/components/limited_account_hint';
import Column from '../ui/components/column';

const mapStateToProps = (state, { params: { acct, id } }) => {
  const accountId = id || state.getIn(['accounts_map', normalizeForLookup(acct)]);

  if (!accountId) {
    return {
      isLoading: true,
    };
  }

  return {
    accountId,
    remote: !!(state.getIn(['accounts', accountId, 'acct']) !== state.getIn(['accounts', accountId, 'username'])),
    remoteUrl: state.getIn(['accounts', accountId, 'url']),
    isAccount: !!state.getIn(['accounts', accountId]),
    accountIds: state.getIn(['user_lists', 'following', accountId, 'items']),
    hasMore: !!state.getIn(['user_lists', 'following', accountId, 'next']),
    isLoading: state.getIn(['user_lists', 'following', accountId, 'isLoading'], true),
    suspended: state.getIn(['accounts', accountId, 'suspended'], false),
    hideCollections: state.getIn(['accounts', accountId, 'hide_collections'], false),
    hidden: getAccountHidden(state, accountId),
    instanceHideReason: state.getIn(['accounts', accountId, 'remote_limit_reason']),
  };
};

const RemoteHint = ({ accountId, url }) => {
  const acct = useAppSelector(state => state.accounts.get(accountId)?.acct);
  const domain = acct ? acct.split('@')[1] : undefined;

  return (
    <TimelineHint
      url={url}
      message={<FormattedMessage id='hints.profiles.follows_may_be_missing' defaultMessage='Follows for this profile may be missing.' />}
      label={<FormattedMessage id='hints.profiles.see_more_follows' defaultMessage='See more follows on {domain}' values={{ domain: <strong>{domain}</strong> }} />}
    />
  );
};

RemoteHint.propTypes = {
  url: PropTypes.string.isRequired,
  accountId: PropTypes.string.isRequired,
};

class Following extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.shape({
      acct: PropTypes.string,
      id: PropTypes.string,
    }).isRequired,
    accountId: PropTypes.string,
    dispatch: PropTypes.func.isRequired,
    accountIds: ImmutablePropTypes.list,
    hasMore: PropTypes.bool,
    isLoading: PropTypes.bool,
    isAccount: PropTypes.bool,
    suspended: PropTypes.bool,
    hidden: PropTypes.bool,
    instanceHideReason: PropTypes.string,
    remote: PropTypes.bool,
    remoteUrl: PropTypes.string,
    multiColumn: PropTypes.bool,
  };

  _load () {
    const { accountId, isAccount, dispatch } = this.props;

    if (!isAccount) dispatch(fetchAccount(accountId));
    dispatch(fetchFollowing(accountId));
  }

  componentDidMount () {
    const { params: { acct }, accountId, dispatch } = this.props;

    if (accountId) {
      this._load();
    } else {
      dispatch(lookupAccount(acct));
    }
  }

  componentDidUpdate (prevProps) {
    const { params: { acct }, accountId, dispatch } = this.props;

    if (prevProps.accountId !== accountId && accountId) {
      this._load();
    } else if (prevProps.params.acct !== acct) {
      dispatch(lookupAccount(acct));
    }
  }

  handleLoadMore = debounce(() => {
    this.props.dispatch(expandFollowing(this.props.accountId));
  }, 300, { leading: true });

  setRef = c => {
    this.column = c;
  };

  handleHeaderClick = () => {
    this.column.scrollTop();
  };

  render () {
    const { accountId, accountIds, hasMore, isAccount, multiColumn, isLoading, suspended, hidden, remote, remoteUrl, hideCollections, instanceHideReason } = this.props;

    if (!isAccount) {
      return (
        <BundleColumnError multiColumn={multiColumn} errorType='routing' />
      );
    }

    if (!accountIds) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    let emptyMessage;

    const forceEmptyState = suspended || hidden;

    if (suspended) {
      emptyMessage = <FormattedMessage id='empty_column.account_suspended' defaultMessage='Account suspended' />;
    } else if (hidden) {
      emptyMessage = <LimitedAccountHint accountId={accountId} reason={instanceHideReason} />;
    } else if (hideCollections && accountIds.isEmpty()) {
      emptyMessage = <FormattedMessage id='empty_column.account_hides_collections' defaultMessage='This user has chosen to not make this information available' />;
    } else if (remote && accountIds.isEmpty()) {
      emptyMessage = <RemoteHint accountId={accountId} url={remoteUrl} />;
    } else {
      emptyMessage = <FormattedMessage id='account.follows.empty' defaultMessage="This user doesn't follow anyone yet." />;
    }

    const remoteMessage = remote ? <RemoteHint accountId={accountId} url={remoteUrl} /> : null;

    return (
      <Column bindToDocument={!multiColumn} ref={this.setRef}>
        <ProfileColumnHeader onClick={this.handleHeaderClick} multiColumn={multiColumn} />

        <ScrollableList
          scrollKey='following'
          hasMore={!forceEmptyState && hasMore}
          isLoading={isLoading}
          onLoadMore={this.handleLoadMore}
          prepend={<AccountHeader accountId={this.props.accountId} hideTabs />}
          alwaysPrepend
          append={remoteMessage}
          emptyMessage={emptyMessage}
          bindToDocument={!multiColumn}
        >
          {accountIds.map(id =>
            <Account key={id} id={id} />,
          )}
        </ScrollableList>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(Following);
