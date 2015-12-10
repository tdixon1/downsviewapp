package org.downsviewsda.downsviewapp;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.support.design.widget.FloatingActionButton;
import android.support.design.widget.Snackbar;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.youtube.player.YouTubeInitializationResult;
import com.google.android.youtube.player.YouTubePlayer;
import com.google.android.youtube.player.YouTubePlayerSupportFragment;
import com.google.android.youtube.player.YouTubePlayerView;

import static android.view.ViewGroup.LayoutParams.MATCH_PARENT;
import static android.view.ViewGroup.LayoutParams.WRAP_CONTENT;

import org.downsviewsda.downsviewapp.data.Contract;

public class SermonDetailActivity extends AppCompatActivity  implements
        LoaderManager.LoaderCallbacks<Cursor> {

    private static final int RECOVERY_DIALOG_REQUEST = 1;
    //Loader stuff
    private final String LOG_TAG = SermonDetailActivity.class.getSimpleName();
    static final String SERMON_URI = "URI";
    private Activity mActivity;

    private Uri mUri;

    private static final int SERMON_LOADER = 0;
    private static final String[] SERMON_COLUMNS = {
            // In this case the id needs to be fully qualified with a table name, since
            // the content provider joins the location & weather tables in the background
            // (both have an _id column)
            // On the one hand, that's annoying.  On the other, you can search the weather table
            // using the location set by the user, which is only in the Location table.
            // So the convenience is worth it.
            Contract.SermonEntry.TABLE_NAME + "." + Contract.SermonEntry._ID,
            Contract.SermonEntry.COLUMN_SERMON_CONTENT,
            Contract.SermonEntry.COLUMN_SERMON_WPID,
            Contract.SermonEntry.COLUMN_SERMON_VIDEOURL,
            Contract.SermonEntry.COLUMN_SERMON_URL,
            Contract.SermonEntry.COLUMN_SERMON_TITLE,
            Contract.SermonEntry.COLUMN_SERMON_SPEAKER,
            Contract.SermonEntry.COLUMN_SERMON_IMAGEURL,
            Contract.SermonEntry.COLUMN_SERMON_DATE

    };

    // These indices are tied to EVENT_COLUMNS.  If EVENT_COLUMNS changes, these
    // must change.
    static final int COL_SERMON_ID = 0;
    static final int COL_SERMON_CONTENT = 1;
    static final int COL_SERMON_WPID = 2;
    static final int COL_SERMON_VIDEOURL = 3;
    static final int COL_SERMON_URL = 4;
    static final int COL_SERMON_TITLE = 5;
    static final int COL_SERMON_SPEAKER = 6;
    static final int COL_SERMON_IMAGEURL = 7;
    static final int COL_SERMON_DATE = 7;

    private static final int PORTRAIT_ORIENTATION = Build.VERSION.SDK_INT < 9
            ? ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            : ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT;

    private LinearLayout baseLayout;
    private YouTubePlayerView playerView;
    private YouTubePlayerSupportFragment playerFrag;
    private YouTubePlayer mPlayer;
    private View otherViews;


    private TextView title;
    private TextView sermonDate;
    private TextView mContent;
    private Toolbar mToolbar;

    private String videoId;

    private boolean fullscreen;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_sermon_detail);
        mToolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(mToolbar);

        FloatingActionButton fab = (FloatingActionButton) findViewById(R.id.fab);
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Snackbar.make(view, "Replace with your own action", Snackbar.LENGTH_LONG)
                        .setAction("Action", null).show();
            }
        });
        getSupportActionBar().setDisplayHomeAsUpEnabled(true);

        mUri = Uri.parse("content://" + Contract.CONTENT_AUTHORITY + "/" + Contract.PATH_SERMON);

        mContent = (TextView)findViewById(R.id.text_sermon_content);
        title = (TextView)findViewById(R.id.sermon_detail_title);
        sermonDate = (TextView)findViewById(R.id.sermon_detail_date);

        mActivity =this;
        getSupportLoaderManager().initLoader(SERMON_LOADER, null, this);
    }

    private void initYoutube(String video)
    {
        playerFrag = (YouTubePlayerSupportFragment) this.getSupportFragmentManager().findFragmentById(R.id.player);
        final String mVideo = video;
        playerFrag.initialize(DeveloperKey.DEVELOPER_KEY, new YouTubePlayer.OnInitializedListener() {
            @Override
            public void onInitializationSuccess(YouTubePlayer.Provider provider, YouTubePlayer player,
                                                boolean wasRestored) {

                mPlayer = player;
                // Specify that we want to handle fullscreen behavior ourselves.
                player.addFullscreenControlFlag(YouTubePlayer.FULLSCREEN_FLAG_CUSTOM_LAYOUT);
                player.setOnFullscreenListener(new YouTubePlayer.OnFullscreenListener() {
                    @Override
                    public void onFullscreen(boolean isFullscreen) {
                        fullscreen = isFullscreen;
                        doLayout();
                    }
                });
                if (!wasRestored) {
                    player.cueVideo(mVideo);
                }
            }

            @Override
            public void onInitializationFailure(YouTubePlayer.Provider provider,
                                                YouTubeInitializationResult errorReason) {
                if (errorReason.isUserRecoverableError()) {
                    errorReason.getErrorDialog(getParent(), RECOVERY_DIALOG_REQUEST).show();
                } else {
                    String errorMessage = String.format(getString(R.string.error_player), errorReason.toString());
                    Toast.makeText(getApplicationContext(), errorMessage, Toast.LENGTH_LONG).show();
                }
            }
        });
    }

    protected YouTubePlayer.Provider getYouTubePlayerProvider() {
        return playerView;
    }

    private void doLayout() {

        if (fullscreen) {
            // When in fullscreen, the visibility of all other views than the player should be set to
            // GONE and the player should be laid out across the whole screen.
            //playerParams.width = LinearLayout.LayoutParams.MATCH_PARENT;
            //playerParams.height = LinearLayout.LayoutParams.MATCH_PARENT;

            otherViews.setVisibility(View.GONE);
        } else {
            // This layout is up to you - this is just a simple example (vertically stacked boxes in
            // portrait, horizontally stacked in landscape).
            otherViews.setVisibility(View.VISIBLE);
            ViewGroup.LayoutParams otherViewsParams = otherViews.getLayoutParams();
            if (getResources().getConfiguration().orientation == Configuration.ORIENTATION_LANDSCAPE) {
                //playerParams.width = otherViewsParams.width = 0;
                //playerParams.height = WRAP_CONTENT;
                otherViewsParams.height = MATCH_PARENT;
                //playerParams.weight = 1;
                baseLayout.setOrientation(LinearLayout.HORIZONTAL);
            } else {
                //playerParams.width = otherViewsParams.width = MATCH_PARENT;
                //playerParams.height = WRAP_CONTENT;
                //playerParams.weight = 0;
                otherViewsParams.height = 0;
                baseLayout.setOrientation(LinearLayout.VERTICAL);
            }
        }
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        doLayout();
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
                    SERMON_COLUMNS,
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
            videoId = data.getString(COL_SERMON_VIDEOURL);
            videoId = videoId.substring(videoId.lastIndexOf('=') + 1);
            title.setText(data.getString(COL_SERMON_TITLE) + " - " + data.getString(COL_SERMON_SPEAKER));
            sermonDate.setText(Utility.getFormattedMonthDay(this, data.getLong(COL_SERMON_DATE)));
            mContent.setText(data.getString(COL_SERMON_CONTENT));
            mToolbar.setTitle(data.getString(COL_SERMON_TITLE) + " - " + data.getString(COL_SERMON_SPEAKER));
            initYoutube(videoId);
        }
    }

    @Override
    public void onLoaderReset(Loader<Cursor> loader) {

    }
}
