package org.downsviewsda.downsviewapp;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Environment;
import android.support.design.widget.Snackbar;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.facebook.drawee.backends.pipeline.Fresco;
import com.facebook.drawee.controller.AbstractDraweeController;
import com.facebook.drawee.view.SimpleDraweeView;
import com.facebook.imagepipeline.common.ResizeOptions;
import com.facebook.imagepipeline.request.ImageRequest;
import com.facebook.imagepipeline.request.ImageRequestBuilder;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.List;

/**
 * Created by terre on 11/25/2015.
 */
public class NewsletterCursorRecyclerAdapter extends CursorRecyclerAdapter<RecyclerView.ViewHolder> {

    private static Context mContext;
    private LayoutInflater mInflater;

    public NewsletterCursorRecyclerAdapter(Context context, Cursor c) {
        super(c);
        mContext = context;
        mInflater = LayoutInflater.from(context);
    }

    static class EventCursorRecyclerViewHolder extends RecyclerView.ViewHolder {

        TextView textView;
        SimpleDraweeView image;
        String newsletterUrl;
        ProgressBar mProgress;

        public EventCursorRecyclerViewHolder(View itemView) {
            super(itemView);
            textView = (TextView) itemView.findViewById(R.id.text_card_title);
            image = (SimpleDraweeView) itemView.findViewById(R.id.img_card_drawee);
            mProgress = (ProgressBar) itemView.findViewById(R.id.Progressbar);

            itemView.setOnClickListener(new View.OnClickListener(){
                @Override
                public void onClick(View v) {
                    RetrievePdfTask task = new RetrievePdfTask();
                    task.setProgressBar(mProgress);
                    task.execute(Utility.pullPdf(newsletterUrl));
                    Snackbar.make(v, "Downloading " + textView.getText(), Snackbar.LENGTH_SHORT).setAction("Action",null).show();
                }
            });
        }
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, Cursor cursor) {
        int position = cursor.getPosition();
        mCursor.moveToPosition(position);
        ((EventCursorRecyclerViewHolder)holder).textView.setText(mCursor.getString(NewsletterFragment.COL_NEWSLETTER_TITLE));
        ((EventCursorRecyclerViewHolder)holder).newsletterUrl = (mCursor.getString(NewsletterFragment.COL_NEWSLETTER_CONTENT));

        int width = 200, height = 200;
        ImageRequest request = ImageRequestBuilder.newBuilderWithSource(Uri.parse(mCursor.getString(NewsletterFragment.COL_NEWSLETTER_IMAGEURL)))
                .setResizeOptions(new ResizeOptions(width, height))
                .build();
        AbstractDraweeController controller = Fresco.newDraweeControllerBuilder()
                .setOldController(((EventCursorRecyclerViewHolder)holder).image.getController())
                .setImageRequest(request)
                .build();
        ((EventCursorRecyclerViewHolder) holder).image.setController(controller);
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View root = mInflater.inflate(R.layout.newsletter_card_item, parent, false);
        EventCursorRecyclerViewHolder holder = new EventCursorRecyclerViewHolder(root);
        return holder;
    }

    static class RetrievePdfTask extends AsyncTask<String, Integer, File> {

        private Exception exception;
        ProgressBar bar;

        public void setProgressBar(ProgressBar bar) {
            this.bar = bar;
        }
        @Override
        protected void onProgressUpdate(Integer... values) {
            super.onProgressUpdate(values);

            if (this.bar != null) {
                if (bar.getVisibility() != View.VISIBLE)
                    bar.setVisibility(View.VISIBLE);
                bar.setProgress(values[0]);
            }
        }

        protected File doInBackground(String... urls) {
            String extStorageDirectory = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).toString();
            File folder = new File(extStorageDirectory, "downsviewsda");
            folder.mkdirs();
            File file = new File(folder, urls[0].substring(urls[0].lastIndexOf("/")+1));
            try {
                //check for file
                if (file.exists() && (file.length() == FileSize(urls[0])))
                    return file;
                file.createNewFile();
            } catch (IOException e1) {
                e1.printStackTrace();
            }
            DownloadFile(urls[0], file);


            return file;
        }

        protected void onPostExecute(File file) {
            // TODO: check this.exception
            // TODO: do something with the feed
            showPdf(file);


        }

        public void showPdf(File file)
        {

            PackageManager packageManager = mContext.getPackageManager();
            Intent testIntent = new Intent(Intent.ACTION_VIEW);
            testIntent.setType("application/pdf");
            List list = packageManager.queryIntentActivities(testIntent, PackageManager.MATCH_DEFAULT_ONLY);
            Intent intent = new Intent();
            intent.setAction(Intent.ACTION_VIEW);
            Uri uri = Uri.fromFile(file);
            intent.setDataAndType(uri, "application/pdf");
            mContext.startActivity(intent);
        }
        public int FileSize(String fileURL)
        {
            int lengthOfFile = 0;
            try{
                URL u = new URL(fileURL);
                HttpURLConnection c = (HttpURLConnection) u.openConnection();
                c.setRequestMethod("GET");
                c.setDoOutput(true);
                c.connect();

                lengthOfFile = c.getContentLength();
            }
            catch (Exception e) {
                e.printStackTrace();
            }
            return lengthOfFile;
        }
        public void DownloadFile(String fileURL, File directory) {
            try {

                FileOutputStream f = new FileOutputStream(directory);
                URL u = new URL(fileURL);
                HttpURLConnection c = (HttpURLConnection) u.openConnection();
                c.setRequestMethod("GET");
                c.setDoOutput(true);
                c.connect();

                int lengthOfFile = c.getContentLength();

                InputStream in = c.getInputStream();

                byte[] buffer = new byte[1024];
                int len1 = 0;
                int total = 0;
                while ((len1 = in.read(buffer)) > 0) {
                    total += len1;
                    f.write(buffer, 0, len1);
                    publishProgress((int) (total * 100 / lengthOfFile));
                }
                bar.setVisibility(View.GONE);
                f.close();
            } catch (Exception e) {
                e.printStackTrace();
            }

        }
    }
}
