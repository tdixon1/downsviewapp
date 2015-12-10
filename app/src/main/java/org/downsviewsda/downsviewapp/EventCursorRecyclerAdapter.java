package org.downsviewsda.downsviewapp;

import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.support.design.widget.Snackbar;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.facebook.drawee.backends.pipeline.Fresco;
import com.facebook.drawee.controller.AbstractDraweeController;
import com.facebook.drawee.view.SimpleDraweeView;
import com.facebook.imagepipeline.common.ResizeOptions;
import com.facebook.imagepipeline.request.ImageRequest;
import com.facebook.imagepipeline.request.ImageRequestBuilder;

/**
 * Created by terre on 11/25/2015.
 */
public class EventCursorRecyclerAdapter extends CursorRecyclerAdapter<RecyclerView.ViewHolder> {

    private Context mContext;
    private LayoutInflater mInflater;

    public EventCursorRecyclerAdapter(Context context, Cursor c) {
        super(c);
        mContext = context;
        mInflater = LayoutInflater.from(context);
    }

    static class EventCursorRecyclerViewHolder extends RecyclerView.ViewHolder {

        TextView textView;
        SimpleDraweeView image;
        long id;

        public EventCursorRecyclerViewHolder(View itemView) {
            super(itemView);
            textView = (TextView) itemView.findViewById(R.id.text_card_title);
            image = (SimpleDraweeView) itemView.findViewById(R.id.img_card_drawee);

            itemView.setOnClickListener(new View.OnClickListener(){
                @Override
                public void onClick(View v) {
                    //Snackbar.make(v,textView.getText(),Snackbar.LENGTH_SHORT).setAction("Action",null).show();
                    Intent detailIntent = new Intent(v.getContext(),EventDetailActivity.class);
                    detailIntent.putExtra("id",id);
                    v.getContext().startActivity(detailIntent);
                }
            });
        }
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, Cursor cursor) {
        int position = cursor.getPosition();

        mCursor.moveToPosition(position);
        ((EventCursorRecyclerViewHolder)holder).id = mCursor.getLong(EventFragment.COL_EVENT_ID);
        ((EventCursorRecyclerViewHolder)holder).textView.setText(mCursor.getString(EventFragment.COL_EVENT_TITLE));

        int width = 200, height = 200;
        ImageRequest request = ImageRequestBuilder.newBuilderWithSource(Uri.parse(mCursor.getString(EventFragment.COL_EVENT_IMG)))
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
        View root = mInflater.inflate(R.layout.card_item, parent, false);
        EventCursorRecyclerViewHolder holder = new EventCursorRecyclerViewHolder(root);
        return holder;
    }
}
