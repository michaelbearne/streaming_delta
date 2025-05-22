defmodule StreamingDelta.Streaming.Source do
  @derive JSON.Encoder
  defmodule Thumbnail do
    @type t :: %__MODULE__{
            name: String.t(),
            storage_path: String.t(),
            height: non_neg_integer,
            width: non_neg_integer,
            type: String.t()
          }

    defstruct [
      :name,
      :storage_path,
      :height,
      :width,
      :type
    ]

    def build(nil), do: nil

    def build(imgs) when is_list(imgs) do
      Enum.map(imgs, &__MODULE__.build/1)
    end

    # def build(%File{} = file) do
    #   %__MODULE__{
    #     name: file.name,
    #     storage_path: file.storage_path,
    #     height: file.height,
    #     width: file.width,
    #     type: file.type
    #   }
    # end

    def build(img) when is_map(img) do
      %__MODULE__{
        name: img["name"],
        storage_path: img["storage_path"],
        height: img["height"],
        width: img["width"],
        type: img["type"]
      }
    end
  end

  defmodule CoverImage do
    @type t :: %__MODULE__{
            name: String.t(),
            storage_path: String.t(),
            height: non_neg_integer,
            width: non_neg_integer,
            type: String.t(),
            derived: [Thumbnail.t()]
          }

    defstruct [
      :name,
      :storage_path,
      :height,
      :width,
      :type,
      :derived
    ]

    def build(nil), do: nil

    def build(imgs) when is_list(imgs) do
      Enum.map(imgs, &__MODULE__.build/1)
    end

    def build(img) when is_map(img) do
      %__MODULE__{
        name: img["name"],
        storage_path: img["storage_path"],
        height: img["height"],
        width: img["width"],
        type: img["type"],
        derived: Thumbnail.build(img["derived"])
      }
    end
  end

  @type t :: %__MODULE__{
          id: String.t(),
          num: non_neg_integer,
          type: :page | :title | :description,
          text: String.t(),
          extracted_txt_file_id: String.t(),
          src_file_id: String.t(),
          src_file_name: String.t(),
          page_num: non_neg_integer,
          publication_id: String.t(),
          publication_type: :insight | :study | :collection,
          cover_image: CoverImage.t(),
          thumbnails: [Thumbnail.t()],
          tokens_count: nil | non_neg_integer
        }

  defstruct [
    :id,
    :num,
    :type,
    :text,
    :extracted_txt_file_id,
    :src_file_id,
    :src_file_name,
    :page_num,
    :publication_id,
    :publication_type,
    :cover_image,
    :thumbnails,
    :tokens_count
  ]

  def tokens_count(sources) when is_list(sources) do
    Enum.map(sources, &(&1.tokens_count || 0)) |> Enum.sum()
  end
end
