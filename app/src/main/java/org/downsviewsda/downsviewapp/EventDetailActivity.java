package org.downsviewsda.downsviewapp;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.design.widget.FloatingActionButton;
import android.support.design.widget.Snackbar;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.view.View;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;
import org.downsviewsda.downsviewapp.data.Contract;

public class EventDetailActivity extends AppCompatActivity implements
        LoaderManager.LoaderCallbacks<Cursor>{

    private final String LOG_TAG = EventDetailActivity.class.getSimpleName();
    static final String EVENT_URI = "URI";
    private Activity mActivity;
    private Uri mUri;

    private static final int EVENT_LOADER = 0;
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

    private TextView mDateView;
    private TextView mContent;
    private Toolbar mToolbar;
    private ImageView mImageView;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_detail);
        mToolbar = (Toolbar) findViewById(R.id.toolbar);
        mImageView = (ImageView)findViewById(R.id.detail_appbar_img);
        setSupportActionBar(mToolbar);


        getSupportActionBar().setDisplayHomeAsUpEnabled(true);

        mUri = Uri.parse("content://" + Contract.CONTENT_AUTHORITY + "/" + Contract.PATH_EVENT);

        mContent = (TextView)findViewById(R.id.event_detail_content);
        mDateView = (TextView)findViewById(R.id.event_detail_date);

        mActivity =this;
        getSupportLoaderManager().initLoader(EVENT_LOADER, null, this);
    }

    @Override
    public Loader<Cursor> onCreateLoader(int id, Bundle args) {
        String selection = Contract.EventEntry._ID + " =? ";
        Intent mIntent =this.getIntent();
        String[] selectionArgs = { String.valueOf(mIntent.getLongExtra("id", -1)) };

        if ( null != mUri ) {
            // Now create and return a CursorLoader that will take care of
            // creating a Cursor for the data being displayed.
            return new CursorLoader(
                    this,
                    mUri,
                    EVENT_COLUMNS,
                    selection,
                    selectionArgs,
                    null
            );
        }
        return null;
    }

    @Override
    public void onLoadFinished(Loader<Cursor> loader, Cursor data) {
        if (data != null && data.moveToFirst()) {
            final String img = data.getString(COL_EVENT_IMG);
            if (!img.equals("null"))
                mImageView.setImageURI(Uri.parse(img));

            final String title = data.getString(COL_EVENT_TITLE);
            final long startDateTime = data.getLong(COL_EVENT_START);
            final long endDateTime = data.getLong(COL_EVENT_END);
            final String content = Utility.pullLinks(data.getString(COL_EVENT_CONTENT));


            if (startDateTime != endDateTime) {
                mDateView.setText(Utility.getFormattedMonthDay(getApplicationContext(),
                        startDateTime) + " - " +
                        Utility.getFormattedMonthDay(getApplicationContext(),
                                endDateTime));
            }
            else
            {
                mDateView.setText(Utility.getFormattedMonthDay(getApplicationContext(),
                        startDateTime));
            }
            mContent.setText(content);

            FloatingActionButton fab = (FloatingActionButton) findViewById(R.id.fab);
            fab.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    Intent sendIntent = new Intent();
                    sendIntent.setAction(Intent.ACTION_SEND);
                    String msg = title + " " +
                            Utility.getFormattedMonthDay(view.getContext(), startDateTime) +
                            " #DownsviewSDA #" + title.replaceAll(" ", "");

                    if (!img.equals("null")) {
                        sendIntent.putExtra(Intent.EXTRA_STREAM, Uri.parse(img));
                        sendIntent.putExtra(Intent.EXTRA_TEXT, msg+ " " +img);
                    }
                    sendIntent.putExtra(Intent.EXTRA_TEXT, msg);
                    sendIntent.setType("text/plain");
                    view.getContext().startActivity(sendIntent);
                }
            });



            mToolbar.setTitle(title);

        }
    }

    @Override
    public void onLoaderReset(Loader<Cursor> loader) {

    }
}
