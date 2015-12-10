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
import android.widget.ImageView;
import android.widget.TextView;

import org.downsviewsda.downsviewapp.data.Contract;

public class NewsDetailActivity extends AppCompatActivity  implements
        LoaderManager.LoaderCallbacks<Cursor>{

    private final String LOG_TAG = EventDetailActivity.class.getSimpleName();
    static final String EVENT_URI = "URI";
    private Activity mActivity;
    private Uri mUri;

    private static final int NEWS_LOADER = 0;
    private static final String[] NEWS_COLUMNS = {
            // In this case the id needs to be fully qualified with a table name, since
            // the content provider joins the location & weather tables in the background
            // (both have an _id column)
            // On the one hand, that's annoying.  On the other, you can search the weather table
            // using the location set by the user, which is only in the Location table.
            // So the convenience is worth it.
            Contract.NewsEntry.TABLE_NAME + "." + Contract.NewsEntry._ID,
            Contract.NewsEntry.COLUMN_NEWS_TITLE,
            Contract.NewsEntry.COLUMN_NEWS_URL,
            Contract.NewsEntry.COLUMN_NEWS_WPID,
            Contract.NewsEntry.COLUMN_NEWS_IMAGEURL,
            Contract.NewsEntry.COLUMN_NEWS_AUTHOR,
            Contract.NewsEntry.COLUMN_NEWS_CONTENT,
            Contract.NewsEntry.COLUMN_NEWS_DATE_PUBLISHED

    };

    // These indices are tied to EVENT_COLUMNS.  If EVENT_COLUMNS changes, these
    // must change.
    static final int COL_NEWS_ID = 0;
    static final int COL_NEWS_TITLE = 1;
    static final int COL_NEWS_URL = 2;
    static final int COL_NEWS_WPID = 3;
    static final int COL_NEWS_IMAGEURL = 4;
    static final int COL_NEWS_AUTHOR = 5;
    static final int COL_NEWS_CONTENT = 6;
    static final int COL_NEWS_DATE_PUBLISHED = 7;

    private TextView mDateView;
    private TextView mContent;
    private Toolbar mToolbar;
    private ImageView mImageView;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_news_detail);
        mToolbar = (Toolbar) findViewById(R.id.toolbar);
        mImageView = (ImageView)findViewById(R.id.detail_appbar_img);
        setSupportActionBar(mToolbar);
        mContent = (TextView)findViewById(R.id.news_detail_content);
        mDateView = (TextView)findViewById(R.id.news_detail_date);

        mActivity =this;

        getSupportActionBar().setDisplayHomeAsUpEnabled(true);
        mUri = Uri.parse("content://" + Contract.CONTENT_AUTHORITY + "/" + Contract.PATH_NEWS);

        getSupportLoaderManager().initLoader(NEWS_LOADER, null, this);
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
                    NEWS_COLUMNS,
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
            final String img = data.getString(COL_NEWS_IMAGEURL);
            if (!img.equals("null"))
                mImageView.setImageURI(Uri.parse(img));

            final String title = data.getString(COL_NEWS_TITLE);

            final String content = Utility.pullLinks(data.getString(COL_NEWS_CONTENT));


            mContent.setText(content);

            FloatingActionButton fab = (FloatingActionButton) findViewById(R.id.fab);
            fab.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    Intent sendIntent = new Intent();
                    sendIntent.setAction(Intent.ACTION_SEND);
                    String msg = title;

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
