package org.downsviewsda.downsviewapp;

import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ListView;

import org.downsviewsda.downsviewapp.data.Contract;
import org.downsviewsda.downsviewapp.data.DbHelper;

/**
 * Created by Terrence on 11/18/2015.
 */
public class EventFragment extends Fragment implements FragmentListInterface, LoaderManager.LoaderCallbacks<Cursor> {
    private EventCursorRecyclerAdapter mAdapter;
    private int mPosition;
    private RecyclerView mRecyclerView;
    LayoutInflater mInflater;
    ViewGroup mContainer;
    Bundle mSavedInstanceState;

    public static final java.lang.String ARG_PAGE = "arg_page";
    private static final int EVENT_LOADER = 0;
    // For the forecast view we're showing only a small subset of the stored data.
    // Specify the columns we need.
    private static final String[] EVENT_COLUMNS = {
            // In this case the id needs to be fully qualified with a table name, since
            // the content provider joins the location & weather tables in the background
            // (both have an _id column)
            // On the one hand, that's annoying.  On the other, you can search the weather table
            // using the location set by the user, which is only in the Location table.
            // So the convenience is worth it.
            Contract.EventEntry.TABLE_NAME + "." + Contract.EventEntry._ID,
            Contract.EventEntry.COLUMN_EVENT_TYPE,
            Contract.EventEntry.COLUMN_EVENT_STARTDATE,
            Contract.EventEntry.COLUMN_EVENT_ENDDATE,
            Contract.EventEntry.COLUMN_EVENT_TITLE,
            Contract.EventEntry.COLUMN_EVENT_WPID,
            Contract.EventEntry.COLUMN_EVENT_IMAGEURL,
            Contract.EventEntry.COLUMN_EVENT_CONTENT

    };

    // These indices are tied to EVENT_COLUMNS.  If EVENT_COLUMNS changes, these
    // must change.
    static final int COL_EVENT_ID = 0;
    static final int COL_EVENT_TYPE = 1;
    static final int COL_EVENT_START = 2;
    static final int COL_EVENT_END = 3;
    static final int COL_EVENT_TITLE = 4;
    static final int COL_EVENT_WPID = 5;
    static final int COL_EVENT_IMG = 6;
    static final int COL_EVENT_CONTENT = 7;
    public EventFragment()
    {

    }
    public static EventFragment newInstance(int pageNumber) {
        EventFragment myFragment = new EventFragment();
        Bundle arguments = new Bundle();
        arguments.putInt(ARG_PAGE, pageNumber + 1);
        myFragment.setArguments(arguments);
        return myFragment;
    }

    @Override
    public void onActivityCreated(Bundle savedInstanceState) {
        getLoaderManager().initLoader(EVENT_LOADER, null, this);
        super.onActivityCreated(savedInstanceState);

        mRecyclerView.setAdapter(mAdapter);
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mPosition = getArguments().getInt(ARG_PAGE);
        // Add this line in order for this fragment to handle menu events.
        setHasOptionsMenu(true);
    }
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        mInflater = inflater;
        mContainer = container;
        mSavedInstanceState = savedInstanceState;
        View rootView = inflater.inflate(R.layout.fragment_event, container, false);
        mAdapter = new EventCursorRecyclerAdapter(getActivity(), null);
        Bundle arguments = getArguments();
        int pageNumber = arguments.getInt(ARG_PAGE);
        mRecyclerView = new RecyclerView(getActivity());
        mRecyclerView.setAdapter(mAdapter);
        mRecyclerView.setLayoutManager(new LinearLayoutManager(getActivity()));
        return mRecyclerView;
    }

    @Override
    public Loader<Cursor> onCreateLoader(int i, Bundle bundle) {
        // This is called when a new Loader needs to be created.  This
        // fragment only uses one loader, so we don't care about checking the id.

        // To only show current and future dates, filter the query to return weather only for
        // dates after or including today.

        // Sort order:  Ascending, by date.
        String sortOrder = Contract.EventEntry.COLUMN_EVENT_STARTDATE + " ASC";

        //String locationSetting = Utility.getPreferredLocation(getActivity());
        //Uri eventsUri = Contract.EventEntry.buildEventUri(System.currentTimeMillis());
        String selection = Contract.EventEntry.COLUMN_EVENT_ENDDATE + " >=? ";
        String[] selectionArgs = { String.valueOf(System.currentTimeMillis()) };

        return new CursorLoader(getActivity(),
                Uri.parse("content://" + Contract.CONTENT_AUTHORITY +"/" + Contract.PATH_EVENT),
                EVENT_COLUMNS,
                selection,
                selectionArgs,
                sortOrder);
    }

    @Override
    public void onLoadFinished(Loader<Cursor> loader, Cursor data) {
        mAdapter.swapCursor(data);
        if (mPosition != ListView.INVALID_POSITION) {
            // If we don't need to restart the loader, and there's a desired position to restore
            // to, do so now.
            mRecyclerView.smoothScrollToPosition(mPosition);
        }
    }

    @Override
    public void onLoaderReset(Loader<Cursor> loader) {
        mAdapter.swapCursor(null);
    }

    @Override
    public void fragmentBecameVisible() {

        onCreateView(mInflater,mContainer,mSavedInstanceState);
    }
}
