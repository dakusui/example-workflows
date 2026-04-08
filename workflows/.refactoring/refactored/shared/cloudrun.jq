def gar_image: "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.SERVICE }}:${{ github.sha }}";
def gar_image_with_repo: "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.SERVICE }}:${{ github.sha }}";
def build_and_push: "docker build -t \"\(gar_image)\" ./\ndocker push \"\(gar_image)\"";
def build_and_push_with_repo: "docker build -t \"\(gar_image_with_repo)\" ./\ndocker push \"\(gar_image_with_repo)\"";
