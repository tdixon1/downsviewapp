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
/**
 * Created by Terrence on 11/18/2015.
 */
public class SermonsFragment extends Fragment implements FragmentListInterface, LoaderManager.LoaderCallbacks<Cursor> {
    private SermonCursorRecyclerAdapter mAdapter;
    private int mPosition;
    private RecyclerView mRecyclerView;
    LayoutInflater mInflater;
    ViewGroup mContainer;
    Bundle mSavedInstanceState;

    public static final String ARG_PAGE = "arg_page";

    private static final int SERMON_LOADER = 0;
    // For the forecast view we're showing only a small subset of the stored data.
// Specify the columns we need.
    private static final String[] SERMONS_COLUMNS = {
            // In this case the id needs to be fully qualified with a table name, since
            // the content provider joins the location & weather tables in the background
            // (both have an _id column)
            // On the one hand, that's annoying.  On the other, you can search the weather table
            // using the location set by the user, which is only in the Location table.
            // So the convenience is worth it.
            Contract.SermonEntry.TABLE_NAME + "." + Contract.SermonEntry._ID,
            Contract.SermonEntry.COLUMN_SERMON_CONTENT,
            Contract.SermonEntry.COLUMN_SERMON_DATE,
            Contract.SermonEntry.COLUMN_SERMON_IMAGEURL,
            Contract.SermonEntry.COLUMN_SERMON_SPEAKER,
            Contract.SermonEntry.COLUMN_SERMON_TITLE,
            Contract.SermonEntry.COLUMN_SERMON_URL,
            Contract.SermonEntry.COLUMN_SERMON_VIDEOURL,
            Contract.SermonEntry.COLUMN_SERMON_WPID

    };

    // These indices are tied to SERMON_COLUMNS.  If NEWS_COLUMNS changes, these
// must change.
    static final int COL_SERMON_ID = 0;
    static final int COL_SERMON_CONTENT = 1;
    static final int COL_SERMON_DATE = 2;
    static final int COL_SERMON_IMAGEURL = 3;
    static final int COL_SERMON_SPEAKER = 4;
    static final int COL_SERMON_TITLE = 5;
    static final int COL_SERMON_URL = 6;
    static final int COL_SERMON_VIDEOURL = 7;
    static final int COL_SERMON_WPID = 8;

    public SermonsFragment()
    {

    }
    public static SermonsFragment newInstance(int pageNumber) {
        SermonsFragment myFragment = new SermonsFragment();
        Bundle arguments = new Bundle();
        arguments.putInt(ARG_PAGE, pageNumber + 1);
        myFragment.setArguments(arguments);
        return myFragment;
    }

    @Override
    public void onActivityCreated(Bundle savedInstanceState) {
        getLoaderManager().initLoader(SERMON_LOADER, null, this);
        super.onActivityCreated(savedInstanceState);

        mRecyclerView.setAdapter(mAdapter);
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mPosition = getArguments().getInt(ARG_PAGE);
        mAdapter = new SermonCursorRecyclerAdapter(getActivity(), null);
        // Add this line in order for this fragment to handle menu events.
        setHasOptionsMenu(true);
    }
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        mInflater = inflater;
        mContainer = container;
        mSavedInstanceState = savedInstanceState;
        View rootView = inflater.inflate(R.layout.fragment_event, container, false);
        Bundle arguments = getArguments();
        int pageNumber = arguments.getInt(ARG_PAGE);
        mRecyclerView = new RecyclerView(getActivity());
        mRecyclerView.setAdapter(mAdapter);
        mRecyclerView.setLayoutManager(new LinearLayoutManager(getActivity()));
        return mRecyclerView;
    }

    @Override
    public Loader<Cursor> onCreateLoader(int id, Bundle args) {
        // This is called when a new Loader needs to be created.  This
        // fragment only uses one loader, so we don't care about checking the id.

        // To only show current and future dates, filter the query to return weather only for
        // dates after or including today.

        // Sort order:  Ascending, by date.
        String sortOrder = Contract.NewsEntry.COLUMN_NEWS_DATE_PUBLISHED + " DESC";

        //String locationSetting = Utility.getPreferredLocation(getActivity());
        //Uri eventsUri = Contract.EventEntry.buildEventUri(System.currentTimeMillis());

        return new CursorLoader(getActivity(),
                Uri.parse("content://" + Contract.CONTENT_AUTHORITY + "/" + Contract.PATH_SERMON),
                SERMONS_COLUMNS,
                null,
                null,
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

    }

    @Override
    public void fragmentBecameVisible() {
        onCreateView(mInflater,mContainer,mSavedInstanceState);
    }
}
